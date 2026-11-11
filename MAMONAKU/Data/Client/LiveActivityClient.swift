import ActivityKit
import Foundation
import os

/// ActivityKit の薄いラッパー。アプリが出す Live Activity（予定スタック 1 つ）の表示・更新・終了を行う。
@MainActor
final class LiveActivityClient {
    /// 現行の Live Activity を識別する `attributes.name`。
    private static let stackName = "timeline-stack"
    /// 旧バージョン（予定ごとに 1 つ出していた頃）の `attributes.name` の接頭辞。
    private static let legacyNamePrefix = "timeline-item:"

    private let pushTokenClient: LiveActivityPushTokenClient
    private let logger = AppLog.liveActivity

    init(pushTokenClient: LiveActivityPushTokenClient) {
        self.pushTokenClient = pushTokenClient
    }

    /// 端末の設定で Live Activity が許可されているか。
    var areActivitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    /// 表示中の Live Activity が先頭に出している予定の開始時刻。表示していなければ nil。
    var displayedPrimaryStartDate: Date? {
        managedActivities.first?.content.state.schedule.first?.nextStartDate
    }

    /// 予定スタックを表示する。表示中なら内容を更新し、無ければ新しく開始する。
    func showStack(schedule: [ActivityTaskItem], staleDate: Date?) async {
        let content = ActivityContent(
            state: MAMONAKULiveActivityAttributes.ContentState(schedule: schedule),
            staleDate: staleDate,
            relevanceScore: 1.0
        )
        let titles = schedule.map(\.nextTitle).joined(separator: " → ")

        if let existing = allActivities.first(where: { $0.attributes.name == Self.stackName }) {
            await existing.update(content)
            logger.info("Local update — schedule: \(titles, privacy: .public)")
            pushTokenClient.observeUpdateToken(for: existing)
            return
        }

        for legacy in allActivities where legacy.attributes.name.hasPrefix(Self.legacyNamePrefix) {
            await legacy.end(nil, dismissalPolicy: .immediate)
        }

        do {
            // 新規 Activity の update トークンは作り直されるため、古いキャッシュでは同期しない
            pushTokenClient.invalidateCachedLiveActivityUpdateToken()
            let created = try Activity.request(
                attributes: MAMONAKULiveActivityAttributes(name: Self.stackName),
                content: content,
                pushType: .token
            )
            logger.info("Created — schedule: \(titles, privacy: .public)")
            pushTokenClient.observeUpdateToken(for: created)
        } catch {
            logger.error("Creation failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// アプリが出した Live Activity をすべて終了する。
    func endAll() async {
        for activity in managedActivities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    // MARK: - Private

    private var allActivities: [Activity<MAMONAKULiveActivityAttributes>] {
        Activity<MAMONAKULiveActivityAttributes>.activities
    }

    private var managedActivities: [Activity<MAMONAKULiveActivityAttributes>] {
        allActivities.filter {
            $0.attributes.name == Self.stackName || $0.attributes.name.hasPrefix(Self.legacyNamePrefix)
        }
    }
}
