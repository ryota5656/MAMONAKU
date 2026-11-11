import Foundation
@testable import MAMONAKU

/// メモリ上に予定を持つ `TimelineRepository`。
@MainActor
final class FakeTimelineRepository: TimelineRepository {
    var items: [TimelineItem]
    private(set) var saveCount = 0
    private(set) var deletedIDs: [UUID] = []
    /// `requestCalendarAccess` の結果
    var isCalendarAccessGranted = true
    private(set) var calendarSyncEnabledHistory: [Bool] = []

    init(items: [TimelineItem] = []) {
        self.items = items
    }

    func fetchItems() -> [TimelineItem] { items }

    func saveItems(_ items: [TimelineItem]) {
        self.items = items
        saveCount += 1
    }

    func deleteItem(id: UUID) {
        items.removeAll { $0.id == id }
        deletedIDs.append(id)
    }

    func requestCalendarAccess() async -> Bool { isCalendarAccessGranted }

    func setCalendarSyncEnabled(_ enabled: Bool) {
        calendarSyncEnabledHistory.append(enabled)
    }
}

/// 呼び出しを記録するだけの `TimelineNotificationRepository`。
@MainActor
final class FakeTimelineNotificationRepository: TimelineNotificationRepository {
    var isAuthorizedValue = false
    /// 許可ダイアログでユーザーが許可するか
    var grantsAuthorization = true
    private(set) var authorizationRequestCount = 0
    private(set) var startRescheduleCount = 0
    private(set) var bufferRescheduleCount = 0
    private(set) var lastRescheduledItems: [TimelineItem] = []

    func isAuthorized() async -> Bool { isAuthorizedValue }

    func requestAuthorizationIfNeeded() async {
        authorizationRequestCount += 1
        isAuthorizedValue = grantsAuthorization
    }

    func rescheduleStartNotifications(items: [TimelineItem]) {
        startRescheduleCount += 1
        lastRescheduledItems = items
    }

    func rescheduleBufferNotifications(items: [TimelineItem]) {
        bufferRescheduleCount += 1
        lastRescheduledItems = items
    }
}

/// 「未反映」の印と反映回数だけを持つ `LiveActivityRepository`。
@MainActor
final class FakeLiveActivityRepository: LiveActivityRepository {
    private(set) var isSyncPending = false
    private(set) var commitSyncCount = 0
    private(set) var refreshIfOverdueCount = 0

    func markSyncPending() {
        isSyncPending = true
    }

    func commitSync() async {
        commitSyncCount += 1
        isSyncPending = false
    }

    func refreshIfOverdue() async {
        refreshIfOverdueCount += 1
    }
}
