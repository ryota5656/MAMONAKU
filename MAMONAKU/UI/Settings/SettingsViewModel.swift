import Foundation
import Observation

/// 設定画面のロジック。設定値の読み書きと、それに伴う通知の再登録・カレンダー同期の切り替えを行う。
///
/// 加入状態と選択中テーマは Screen から `environmentDidChange` で受け取る
/// （どちらもアプリ全体で共有する `SubscriptionManager` / `ThemeManager` が持つため）。
@Observable
@MainActor
final class SettingsViewModel: SettingsDelegate {
    /// View 側で実行する副作用の指示。実行後に `handleRouteConsumed` を呼ぶ。
    enum Route: Equatable {
        case openURL(URL)
        /// iOS の設定アプリで、このアプリの設定を開く
        case openSystemSettings
        case applyTheme(AppPalette)
        case setDebugSubscriptionOverride(Bool)
    }

    private enum Link {
        static let feedback = URL(string: "mailto:kopernix5656@icloud.com")
        static let terms = URL(string: "https://note.com/quirky_magpie934/n/n7746f82a9f27")
        static let privacyPolicy = URL(string: "https://note.com/quirky_magpie934/n/naec276dc2d9b")
    }

    /// バッファ分を増減する刻み
    private static let bufferStepMinutes = 5

    // MARK: - State

    private(set) var state = SettingsViewState()
    private(set) var route: Route?

    // MARK: - Dependencies

    @ObservationIgnored private let settings: AppSettingsClient
    @ObservationIgnored private let timelineRepository: TimelineRepository
    @ObservationIgnored private let notificationRepository: TimelineNotificationRepository

    init(
        settings: AppSettingsClient,
        timelineRepository: TimelineRepository,
        notificationRepository: TimelineNotificationRepository
    ) {
        self.settings = settings
        self.timelineRepository = timelineRepository
        self.notificationRepository = notificationRepository
        state.isSubscribed = settings.isSubscribed
        reloadSettings()
    }

    // MARK: - Screen からの通知

    func onAppear() async {
        reloadSettings()
        await refreshNotificationPermission()
    }

    /// 加入状態・選択中テーマが変わった（画面表示時にも呼ぶ）。
    func environmentDidChange(
        isSubscribed: Bool,
        selectedTheme: AppPalette,
        isDebugSubscriptionOverridden: Bool
    ) {
        state.isSubscribed = isSubscribed
        state.selectedTheme = selectedTheme
        state.isDebugSubscriptionOverridden = isDebugSubscriptionOverridden
    }

    func dismissSubscriptionSheet() {
        state.isSubscriptionSheetPresented = false
    }

    func handleRouteConsumed() {
        route = nil
    }

    // MARK: - SettingsDelegate

    func settingsDidTapSubscription() {
        state.isSubscriptionSheetPresented = true
    }

    func settingsDidTapLockedFeature() {
        state.isSubscriptionSheetPresented = true
    }

    func settingsDidSelectTheme(_ theme: AppPalette) {
        if state.canSelectTheme(theme) {
            route = .applyTheme(theme)
        } else {
            state.isSubscriptionSheetPresented = true
        }
    }

    func settingsDidToggleCalendarSync(_ isOn: Bool) {
        guard state.isSubscribed else { return }
        guard isOn else {
            setCalendarSyncEnabled(false)
            return
        }
        // オンにできるのは、標準カレンダーへのアクセスが許可された場合だけ。
        Task {
            setCalendarSyncEnabled(await timelineRepository.requestCalendarAccess())
        }
    }

    func settingsDidToggleNotificationPermission(_ isOn: Bool) {
        if isOn {
            Task {
                await notificationRepository.requestAuthorizationIfNeeded()
                await refreshNotificationPermission()
            }
        } else {
            // アプリからは許可を取り消せないため、設定アプリへ案内する。
            route = .openSystemSettings
            Task { await refreshNotificationPermission() }
        }
    }

    func settingsDidToggleStartNotification(_ isOn: Bool) {
        state.isStartNotificationEnabled = isOn
        settings.isStartNotificationEnabled = isOn
        notificationRepository.rescheduleStartNotifications(items: timelineRepository.fetchItems())
    }

    func settingsDidToggleLiveActivity(_ isOn: Bool) {
        state.isLiveActivityEnabled = isOn
        settings.isLiveActivityEnabled = isOn
    }

    func settingsDidToggleLiveActivityStack(_ isOn: Bool) {
        guard state.isSubscribed else { return }
        state.isLiveActivityStackEnabled = isOn
        settings.isLiveActivityStackPreferred = isOn
    }

    func settingsDidToggleBufferNotification(_ isOn: Bool) {
        guard state.isSubscribed else { return }
        state.isBufferNotificationEnabled = isOn
        settings.isBufferNotificationPreferred = isOn
        rescheduleBufferNotifications()
    }

    /// バッファ分を +5 する。5 分未満（1 分）からは 5 分にする。
    func settingsDidIncrementBufferMinutes() {
        let step = Self.bufferStepMinutes
        setBufferMinutes(state.bufferMinutes < step ? step : state.bufferMinutes + step)
    }

    /// バッファ分を -5 する。5 分以下からは最短の 1 分にする。
    func settingsDidDecrementBufferMinutes() {
        let step = Self.bufferStepMinutes
        setBufferMinutes(
            state.bufferMinutes <= step
                ? AppSettingsClient.bufferMinutesRange.lowerBound
                : state.bufferMinutes - step
        )
    }

    func settingsDidTapFeedback() {
        open(Link.feedback)
    }

    func settingsDidTapTerms() {
        open(Link.terms)
    }

    func settingsDidTapPrivacyPolicy() {
        open(Link.privacyPolicy)
    }

    func settingsDidToggleDebugSubscription(_ isOn: Bool) {
        route = .setDebugSubscriptionOverride(isOn)
    }

    // MARK: - Private

    private func reloadSettings() {
        state.isCalendarSyncEnabled = settings.isCalendarSyncPreferred
        state.isStartNotificationEnabled = settings.isStartNotificationEnabled
        state.isLiveActivityEnabled = settings.isLiveActivityEnabled
        state.isLiveActivityStackEnabled = settings.isLiveActivityStackPreferred
        state.isBufferNotificationEnabled = settings.isBufferNotificationPreferred
        state.bufferMinutes = settings.globalBufferMinutes
    }

    private func refreshNotificationPermission() async {
        state.isNotificationPermissionGranted = await notificationRepository.isAuthorized()
    }

    private func setCalendarSyncEnabled(_ isEnabled: Bool) {
        state.isCalendarSyncEnabled = isEnabled
        timelineRepository.setCalendarSyncEnabled(isEnabled)
    }

    private func setBufferMinutes(_ minutes: Int) {
        guard state.isSubscribed else { return }
        let clamped = AppSettingsClient.clampBufferMinutes(minutes)
        state.bufferMinutes = clamped
        settings.globalBufferMinutes = clamped
        rescheduleBufferNotifications()
    }

    private func rescheduleBufferNotifications() {
        notificationRepository.rescheduleBufferNotifications(items: timelineRepository.fetchItems())
    }

    private func open(_ url: URL?) {
        guard let url else { return }
        route = .openURL(url)
    }
}
