import UIKit
import UserNotifications

/// 通知許可とリモート通知登録をまとめる。
enum NotificationAuthorizationService {
    /// 許可ダイアログなしで APNs 登録だけ行う（起動時用）。
    @MainActor
    static func registerForRemoteNotifications() {
        UIApplication.shared.registerForRemoteNotifications()
    }

    /// 未決定のときだけシステム許可ダイアログを出し、その後 APNs 登録する。
    @MainActor
    static func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
                print("[Push] Notification authorization granted: \(granted)")
            } catch {
                print("[Push] Notification authorization failed: \(error.localizedDescription)")
            }
        }
        registerForRemoteNotifications()
    }
}
