import Foundation
import UserNotifications

/// タイムライン予定の開始前（バッファ時間）にローカル通知をスケジュールする
final class TimelineBufferNotificationScheduler {
    private static let defaultGlobalBufferMinutes = 10
    private static let minBufferMinutes = 1
    private static let maxBufferMinutes = 120

    private let bufferNotificationIDPrefix = "timeline.buffer.notification."
    private let legacySoonNotificationID = "liveActivity.soon.notification"
    private let maximumScheduledNotifications = 60

    private var appGroupDefaults: UserDefaults? {
        UserDefaults(suiteName: AppGroup.id)
    }

    private var isBufferNotificationEnabled: Bool {
        let isSubscribed = appGroupDefaults?.bool(forKey: SubscriptionManager.subscriptionStateUserDefaultsKey) ?? false
        let isEnabledByUser = appGroupDefaults?.object(forKey: AppGroup.bufferNotificationEnabledKey) as? Bool ?? false
        return isSubscribed && isEnabledByUser
    }

    private var globalBufferMinutes: Int {
        let value = appGroupDefaults?.object(forKey: AppGroup.globalBufferMinutesKey) as? Int
            ?? Self.defaultGlobalBufferMinutes
        return min(max(value, Self.minBufferMinutes), Self.maxBufferMinutes)
    }

    func reschedule(items: [TimelineItem]) {
        guard isBufferNotificationEnabled else {
            cancel()
            return
        }

        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                self.replacePendingNotifications(with: items)
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    guard granted else { return }
                    self.replacePendingNotifications(with: items)
                }
            default:
                break
            }
        }
    }

    func cancel() {
        removePendingBufferNotifications {
        }
    }

    private func replacePendingNotifications(with items: [TimelineItem]) {
        removePendingBufferNotifications {
            self.scheduleBufferNotifications(items: items)
        }
    }

    private func removePendingBufferNotifications(completion: @escaping () -> Void) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let ids = requests
                .map(\.identifier)
                .filter {
                    $0.hasPrefix(self.bufferNotificationIDPrefix)
                        || $0 == self.legacySoonNotificationID
                }
            if !ids.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: ids)
            }
            completion()
        }
    }

    private func scheduleBufferNotifications(items: [TimelineItem]) {
        let calendar = Calendar.current
        let now = Date()
        let bufferMinutes = globalBufferMinutes
        let scheduledItems: [(item: TimelineItem, triggerDate: Date)] = items
            .compactMap { item in
                guard !item.isAllDay else { return nil }
                guard let startDate = startDate(for: item, calendar: calendar) else { return nil }
                let triggerDate = startDate.addingTimeInterval(TimeInterval(-bufferMinutes * 60))
                guard triggerDate > now else { return nil }
                return (item, triggerDate)
            }
            .sorted { $0.triggerDate < $1.triggerDate }

        for (item, triggerDate) in scheduledItems.prefix(maximumScheduledNotifications) {
            let content = UNMutableNotificationContent()
            content.title = "まもなく開始"
            content.body = "まもなく「\(item.title)」です。準備をしましょう"
            content.sound = .default
            if #available(iOS 15.0, *) {
                content.interruptionLevel = .timeSensitive
            }

            let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: triggerDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let request = UNNotificationRequest(
                identifier: "\(bufferNotificationIDPrefix)\(item.id.uuidString)",
                content: content,
                trigger: trigger
            )
            UNUserNotificationCenter.current().add(request)
        }
    }

    private func startDate(for item: TimelineItem, calendar: Calendar) -> Date? {
        guard let dropDate = item.dropDate, let startMinutes = item.startMinutes else { return nil }
        return calendar.date(byAdding: .minute, value: startMinutes, to: calendar.startOfDay(for: dropDate))
    }
}
