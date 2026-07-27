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

        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self

        Task { @MainActor in
            await requestNotificationAuthorization(application: application)
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

    private func requestNotificationAuthorization(application: UIApplication) async {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound]
            )
            print("[Push] Notification authorization granted: \(granted)")
        } catch {
            print("[Push] Notification authorization failed: \(error.localizedDescription)")
        }

        application.registerForRemoteNotifications()
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
