import Foundation
import os

/// 端末上の Live Activity 更新（`LiveActivityClient`）とサーバーへの予定同期（`ScheduleFirestoreClient`）をまとめる。
///
/// 通常、予定の開始時刻ごとの切り替えはサーバーからのプッシュで行われる。
/// サーバーへの同期に失敗している間だけ、端末側のタイマーで切り替える（ローカルローテーション）。
@MainActor
final class LiveActivityRepositoryImpl: LiveActivityRepository {
    private let timelineRepository: TimelineRepository
    private let settings: AppSettingsClient
    private let liveActivityClient: LiveActivityClient
    private let scheduleClient: ScheduleFirestoreClient
    private let logger = AppLog.liveActivity
    private var localRotationTask: Task<Void, Never>?

    init(
        timelineRepository: TimelineRepository,
        settings: AppSettingsClient,
        liveActivityClient: LiveActivityClient,
        scheduleClient: ScheduleFirestoreClient
    ) {
        self.timelineRepository = timelineRepository
        self.settings = settings
        self.liveActivityClient = liveActivityClient
        self.scheduleClient = scheduleClient
    }

    var isSyncPending: Bool {
        settings.isLiveActivitySyncPending
    }

    func markSyncPending() {
        guard settings.isLiveActivityEnabled else { return }
        settings.isLiveActivitySyncPending = true
    }

    func commitSync() async {
        guard settings.isLiveActivityEnabled else {
            settings.isLiveActivitySyncPending = false
            cancelLocalRotation()
            return
        }

        let items = timelineRepository.fetchItems()
        let rotations = await updateLocalActivity(items: items, schedulesLocalRotation: false)
        do {
            try await scheduleClient.syncSchedules(
                items: items,
                maxVisibleSlots: settings.liveActivityPlanScope.maxVisibleSlots,
                requestsRebuild: true
            )
            cancelLocalRotation()
            settings.isLiveActivitySyncPending = false
            logger.info("Cloud sync succeeded — rotations will come from APNs only")
        } catch {
            if let rotations {
                scheduleNextLocalRotation(rotations)
            }
            settings.isLiveActivitySyncPending = true
            logger.error("Cloud sync failed — local rotation fallback enabled: \(error.localizedDescription, privacy: .public)")
        }
    }

    func syncAllSchedules() async {
        let items = timelineRepository.fetchItems()
        do {
            try await scheduleClient.syncSchedules(
                items: items,
                maxVisibleSlots: settings.liveActivityPlanScope.maxVisibleSlots,
                requestsRebuild: false
            )
        } catch {
            logger.error("Schedule sync failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func refreshIfOverdue() async {
        guard settings.isLiveActivityEnabled, liveActivityClient.areActivitiesEnabled else { return }
        guard let primaryStartDate = liveActivityClient.displayedPrimaryStartDate,
              primaryStartDate <= Date()
        else { return }

        // 表示の直しのみ。以降の切り替えはサーバーからのプッシュ（または同期失敗時のローカルローテーション）に任せる。
        await updateLocalActivity(items: timelineRepository.fetchItems(), schedulesLocalRotation: false)
    }

    // MARK: - 端末上の更新

    /// 今日の予定から Live Activity を表示し直す。表示する予定が無ければ終了する。
    /// - Parameter schedulesLocalRotation: true のとき、次の切り替えを端末側で予約する。
    /// - Returns: 以降の切り替え予定。Live Activity を表示しなかった場合は nil。
    @discardableResult
    private func updateLocalActivity(
        items: [TimelineItem],
        schedulesLocalRotation: Bool
    ) async -> [LiveActivityScheduleBuilder.Rotation]? {
        guard settings.isLiveActivityEnabled else {
            await endActivity()
            return nil
        }
        guard liveActivityClient.areActivitiesEnabled else { return nil }

        let now = Date()
        let planScope = settings.liveActivityPlanScope
        let entries = LiveActivityScheduleBuilder.entriesForToday(items: items, referenceDate: now)
        let (startIndex, window) = LiveActivityScheduleBuilder.currentWindow(
            entries: entries,
            now: now,
            planScope: planScope
        )
        guard !window.isEmpty else {
            await endActivity()
            return nil
        }

        let bufferMinutes: (TimelineItem) -> Int? = { [settings] item in
            settings.effectiveBufferMinutes(itemOverride: item.bufferMinutes)
        }
        let schedule = LiveActivityScheduleBuilder.buildTaskItems(from: window, now: now, bufferMinutes: bufferMinutes)
        let rotations = LiveActivityScheduleBuilder.buildRotations(
            entries: entries,
            startIndex: startIndex,
            now: now,
            planScope: planScope,
            bufferMinutes: bufferMinutes
        )

        await liveActivityClient.showStack(schedule: schedule, staleDate: entries[startIndex].startDate)

        if schedulesLocalRotation {
            scheduleNextLocalRotation(rotations)
        } else {
            cancelLocalRotation()
        }
        return rotations
    }

    private func endActivity() async {
        cancelLocalRotation()
        await liveActivityClient.endAll()
    }

    // MARK: - ローカルローテーション（サーバー同期に失敗している間の代替）

    private func scheduleNextLocalRotation(_ rotations: [LiveActivityScheduleBuilder.Rotation]) {
        cancelLocalRotation()

        guard let next = rotations
            .filter({ $0.switchAt > Date() })
            .min(by: { $0.switchAt < $1.switchAt })
        else { return }

        localRotationTask = Task { [weak self] in
            let delay = next.switchAt.timeIntervalSinceNow
            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
            guard !Task.isCancelled else { return }
            await self?.performLocalRotation(next)
        }
        logger.info("Local rotation fallback scheduled (\(next.reason, privacy: .public))")
    }

    private func cancelLocalRotation() {
        localRotationTask?.cancel()
        localRotationTask = nil
    }

    private func performLocalRotation(_ rotation: LiveActivityScheduleBuilder.Rotation) async {
        if rotation.shouldEndActivity {
            await endActivity()
            return
        }
        // まだサーバーへ同期できていなければ、次の切り替えも端末側で予約し続ける。
        await updateLocalActivity(
            items: timelineRepository.fetchItems(),
            schedulesLocalRotation: settings.isLiveActivitySyncPending
        )
    }
}
