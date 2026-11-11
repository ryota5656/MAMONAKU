import Foundation
import UserNotifications

/// `TimelineNotificationPlanner` が決めた通知を `UNUserNotificationCenter` に登録する。
///
/// 登録し直すたびに、その種類の登録済み通知をすべて消してから入れ直す。
/// 通知許可が未決定の場合は、ここで許可を求める。
///
/// `UNUserNotificationCenter` の完了ハンドラはバックグラウンドスレッドで呼ばれる。
/// 変更可能な状態を持たないので、スレッドをまたいで使えるよう `@unchecked Sendable` にしている。
nonisolated final class TimelineNotificationRepositoryImpl: TimelineNotificationRepository, @unchecked Sendable {
    private let settings: AppSettingsClient
    private let center: UNUserNotificationCenter

    init(settings: AppSettingsClient, center: UNUserNotificationCenter) {
        self.settings = settings
        self.center = center
    }

    func isAuthorized() async -> Bool {
        Self.allowsScheduling(await center.notificationSettings().authorizationStatus)
    }

    func requestAuthorizationIfNeeded() async {
        await NotificationAuthorizationClient.requestAuthorizationIfNeeded()
    }

    func rescheduleStartNotifications(items: [TimelineItem]) {
        reschedule(.start, items: items)
    }

    func rescheduleBufferNotifications(items: [TimelineItem]) {
        reschedule(.buffer, items: items)
    }

    // MARK: - Private

    private static func allowsScheduling(_ status: UNAuthorizationStatus) -> Bool {
        switch status {
        case .authorized, .provisional, .ephemeral: return true
        default: return false
        }
    }

    private func isEnabled(_ kind: TimelineNotificationKind) -> Bool {
        switch kind {
        case .start: return settings.isStartNotificationEnabled
        case .buffer: return settings.isBufferNotificationEnabled
        }
    }

    private func reschedule(_ kind: TimelineNotificationKind, items: [TimelineItem]) {
        guard isEnabled(kind) else {
            removePending(kind) {}
            return
        }

        center.getNotificationSettings { notificationSettings in
            let status = notificationSettings.authorizationStatus
            if Self.allowsScheduling(status) {
                self.replacePending(kind, items: items)
            } else if status == .notDetermined {
                self.center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    guard granted else { return }
                    self.replacePending(kind, items: items)
                }
            }
        }
    }

    private func replacePending(_ kind: TimelineNotificationKind, items: [TimelineItem]) {
        removePending(kind) {
            let plans = TimelineNotificationPlanner.plans(
                kind: kind,
                items: items,
                now: Date(),
                isPlusSubscriber: self.settings.isSubscribed,
                bufferMinutes: self.settings.globalBufferMinutes
            )
            plans.forEach(self.add)
        }
    }

    private func removePending(_ kind: TimelineNotificationKind, completion: @escaping () -> Void) {
        center.getPendingNotificationRequests { requests in
            let identifiers = requests.map(\.identifier).filter(kind.owns(identifier:))
            if !identifiers.isEmpty {
                self.center.removePendingNotificationRequests(withIdentifiers: identifiers)
            }
            completion()
        }
    }

    private func add(_ plan: TimelineNotificationPlan) {
        let content = UNMutableNotificationContent()
        content.title = plan.title
        content.body = plan.body
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: plan.fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        center.add(UNNotificationRequest(identifier: plan.identifier, content: content, trigger: trigger))
    }
}
