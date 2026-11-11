import UIKit
import UserNotifications
import os

/// 通知許可とリモート通知登録をまとめる。
@MainActor
enum NotificationAuthorizationClient {
    /// 許可ダイアログなしで APNs 登録だけ行う（起動時用）。
    static func registerForRemoteNotifications() {
        UIApplication.shared.registerForRemoteNotifications()
    }

    /// 未決定のときだけシステム許可ダイアログを出し、その後 APNs 登録する。
    static func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
                AppLog.push.info("Notification authorization granted: \(granted, privacy: .public)")
            } catch {
                AppLog.push.error("Notification authorization failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        registerForRemoteNotifications()
    }
}
