import Foundation
import UserNotifications

/// アプリで共有するオブジェクトを組み立てて保持する（依存の注入元）。
///
/// 具体クラスの生成はここに集約し、ViewModel やリポジトリは必要なものを引数で受け取る。
/// Firebase を使うものは `FirebaseApp.configure()` より後に作られるよう `lazy` にしている。
@MainActor
final class AppContainer {
    // MARK: - 設定・状態

    /// App Group の UserDefaults（設定値・加入状態・各種トークン）
    let settings: AppSettingsClient
    /// アプリ専用の UserDefaults（起動回数・チュートリアル完了など）
    private let localDefaults: UserDefaults

    let subscriptionManager: SubscriptionManager
    let themeManager: ThemeManager

    init(
        settings: AppSettingsClient = AppSettingsClient(),
        localDefaults: UserDefaults = .standard
    ) {
        self.settings = settings
        self.localDefaults = localDefaults
        self.subscriptionManager = SubscriptionManager(settings: settings)
        self.themeManager = ThemeManager(settings: settings)
    }

    // MARK: - Client

    private(set) lazy var authClient = FirebaseAuthClient(defaults: settings.defaults)
    private(set) lazy var pushTokenClient = LiveActivityPushTokenClient(defaults: settings.defaults)

    private lazy var scheduleClient = ScheduleFirestoreClient(
        authClient: authClient,
        pushTokenClient: pushTokenClient
    )
    private lazy var liveActivityClient = LiveActivityClient(pushTokenClient: pushTokenClient)

    // MARK: - Repository

    /// 画面をまたいで 1 つだけ持つ（標準カレンダー同期を二重に動かさないため）。
    private lazy var timelineRepository: TimelineRepository = {
        let realmClient = TimelineRealmClient(realmProvider: RealmProvider())
        return TimelineRepositoryImpl(
            realmClient: realmClient,
            settings: settings,
            calendarSync: CalendarSyncClient(realmClient: realmClient, settings: settings)
        )
    }()

    private lazy var notificationRepository: TimelineNotificationRepository = TimelineNotificationRepositoryImpl(
        settings: settings,
        center: .current()
    )

    private lazy var liveActivityRepository: LiveActivityRepository = LiveActivityRepositoryImpl(
        timelineRepository: timelineRepository,
        settings: settings,
        liveActivityClient: liveActivityClient,
        scheduleClient: scheduleClient
    )

    // MARK: - ViewModel

    private(set) lazy var contentViewModel = ContentViewModel(userDefaults: localDefaults)

    private(set) lazy var timelineViewModel = TimelineViewModel(
        repository: timelineRepository,
        notificationRepository: notificationRepository,
        liveActivityRepository: liveActivityRepository,
        localDefaults: localDefaults
    )

    private(set) lazy var settingsViewModel = SettingsViewModel(
        settings: settings,
        timelineRepository: timelineRepository,
        notificationRepository: notificationRepository
    )
}
