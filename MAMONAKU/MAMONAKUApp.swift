import SwiftUI
import FirebaseCore
import FirebaseMessaging
import UserNotifications
import os

/// 起動時の初期化（Firebase・プッシュ通知の登録）と、プッシュ関連のコールバックを受ける。
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    /// アプリで共有するオブジェクト。`MAMONAKUApp` からも参照する。
    let container = AppContainer()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        AppLog.app.debug(
            "Firebase env=\(AppEnvironment.name.rawValue, privacy: .public) project=\(AppEnvironment.firebaseProjectID, privacy: .public)"
        )

        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self

        Task { @MainActor in
            // 起動直後は許可ダイアログを出さず、APNs 登録のみ行う。
            // 通知許可は初回チュートリアル完了後（または設定）で取得する。
            NotificationAuthorizationClient.registerForRemoteNotifications()
            await container.authClient.bootstrap()
            container.pushTokenClient.startObserving()
        }

        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
        let apnsToken = deviceToken.map { String(format: "%02x", $0) }.joined()
        AppLog.push.info("APNs device token: \(AppLog.tokenForManualTesting(apnsToken), privacy: .public)")
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        AppLog.push.error("Failed to register for remote notifications: \(error.localizedDescription, privacy: .public)")
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else { return }
        Task { @MainActor in
            container.pushTokenClient.setFCMToken(fcmToken)
        }
    }
}

@main
struct MAMONAKUApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @Environment(\.scenePhase) private var scenePhase

    private var container: AppContainer { delegate.container }

    var body: some Scene {
        WindowGroup {
            ContentView(
                viewModel: container.contentViewModel,
                timelineViewModel: container.timelineViewModel,
                settingsViewModel: container.settingsViewModel
            )
            .appThemeProvider()
            .environmentObject(container.subscriptionManager)
            .environmentObject(container.themeManager)
            .onChange(of: scenePhase) { _, newPhase in
                // 前面に戻ったら加入状態と Live Activity の表示を最新にする。
                // バックグラウンド遷移では同期しない（不安定化回避。完了/更新ボタンで同期）。
                guard newPhase == .active else { return }
                Task {
                    await container.subscriptionManager.updateSubscriptionStatus()
                }
                Task {
                    await container.timelineViewModel.sceneDidBecomeActive()
                }
            }
        }
    }
}
