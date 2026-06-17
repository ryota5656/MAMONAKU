import Foundation
import UserNotifications

/// タイムライン予定の開始時刻に合わせてローカル通知をスケジュールする
final class TimelineStartNotificationScheduler {
    private let startNotificationIDPrefix = "timeline.start.notification."
    private let legacyStartNotificationIDPrefix = "liveActivity.start.notification."
    private let maximumScheduledNotifications = 60

    private var appGroupDefaults: UserDefaults? {
        UserDefaults(suiteName: AppGroup.id)
    }

    private var isStartNotificationEnabled: Bool {
        appGroupDefaults?.object(forKey: AppGroup.startNotificationEnabledKey) as? Bool ?? true
    }

    func reschedule(items: [TimelineItem]) {
        guard isStartNotificationEnabled else {
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
        removePendingStartNotifications {
        }
    }

    private func replacePendingNotifications(with items: [TimelineItem]) {
        removePendingStartNotifications {
            self.scheduleStartNotifications(items: items)
        }
    }

    private func removePendingStartNotifications(completion: @escaping () -> Void) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let ids = requests
                .map(\.identifier)
                .filter {
                    $0.hasPrefix(self.startNotificationIDPrefix)
                        || $0.hasPrefix(self.legacyStartNotificationIDPrefix)
                }
            if !ids.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: ids)
            }
            completion()
        }
    }

    private func scheduleStartNotifications(items: [TimelineItem]) {
        let calendar = Calendar.current
        let now = Date()
        let scheduledItems: [(item: TimelineItem, startDate: Date)] = items
            .compactMap { item in
                guard !item.isAllDay else { return nil }
                guard let startDate = startDate(for: item, calendar: calendar), startDate > now else { return nil }
                return (item, startDate)
            }
            .sorted { $0.startDate < $1.startDate }

        for (item, startDate) in scheduledItems.prefix(maximumScheduledNotifications) {
            let content = UNMutableNotificationContent()
            content.title = "予定の開始時間です"
            content.body = "「\(item.title)」を開始しましょう"
            content.sound = .default
            if #available(iOS 15.0, *) {
                content.interruptionLevel = .timeSensitive
            }

            let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: startDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let request = UNNotificationRequest(
                identifier: "\(startNotificationIDPrefix)\(item.id.uuidString)",
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
