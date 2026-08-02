import SwiftUI
import FirebaseCore
import FirebaseMessaging
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        #if DEBUG
        print("[Firebase] env=\(AppEnvironment.name.rawValue) project=\(AppEnvironment.firebaseProjectID)")
        #endif

        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self

        Task { @MainActor in
            // 起動直後は許可ダイアログを出さず、APNs 登録のみ行う。
            // 通知許可は初回チュートリアル完了後（または設定）で取得する。
            NotificationAuthorizationService.registerForRemoteNotifications()
            await FirebaseAnonymousAuthService.shared.bootstrap()
            LiveActivityPushService.shared.startObserving()
        }

        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
        let apnsToken = deviceToken.map { String(format: "%02x", $0) }.joined()
        print("[Push] APNs Device Token: \(apnsToken)")
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("[Push] Failed to register for remote notifications: \(error.localizedDescription)")
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else { return }
        print("[Push] FCM Registration Token received: \(fcmToken.prefix(8))…\(fcmToken.suffix(4)) (\(fcmToken.count) chars)")
        Task { @MainActor in
            LiveActivityPushService.shared.setFCMToken(fcmToken)
        }
    }
}

@main
struct MAMONAKUApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var subscriptionManager = SubscriptionManager()
    @StateObject private var themeManager = ThemeManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(subscriptionManager)
                .environmentObject(themeManager)
                .onChange(of: scenePhase) { _, newPhase in
                    switch newPhase {
                    case .active:
                        Task {
                            await subscriptionManager.updateSubscriptionStatus()
                        }
                        LiveActivitySyncCoordinator.requestForegroundRefresh()
                    case .background:
                        // バックグラウンド遷移では同期しない（不安定化回避。完了/更新ボタンで同期）
                        break
                    default:
                        break
                    }
                }
        }
    }
}
