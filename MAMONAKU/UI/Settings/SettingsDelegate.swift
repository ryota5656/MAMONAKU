import Foundation

/// 設定画面（`SettingsScreenContent`）で起きたユーザー操作の通知先。
@MainActor
protocol SettingsDelegate: AnyObject {
    func settingsDidTapSubscription()
    /// PLUS 限定の設定（未加入で鍵が掛かっている行）をタップした。
    func settingsDidTapLockedFeature()

    func settingsDidSelectTheme(_ theme: AppPalette)
    func settingsDidToggleCalendarSync(_ isOn: Bool)
    func settingsDidToggleNotificationPermission(_ isOn: Bool)
    func settingsDidToggleStartNotification(_ isOn: Bool)
    func settingsDidToggleLiveActivity(_ isOn: Bool)
    func settingsDidToggleLiveActivityStack(_ isOn: Bool)
    func settingsDidToggleBufferNotification(_ isOn: Bool)
    func settingsDidIncrementBufferMinutes()
    func settingsDidDecrementBufferMinutes()

    func settingsDidTapFeedback()
    func settingsDidTapTerms()
    func settingsDidTapPrivacyPolicy()

    /// DEBUG ビルドの「PLUS 加入をシミュレート」を切り替えた。
    func settingsDidToggleDebugSubscription(_ isOn: Bool)
}
