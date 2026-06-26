import Foundation

/// 設定画面の表示状態。Screen と 1:1。
struct SettingsViewState: Equatable {
    var showSubscriptionSheet: Bool
    var subscriptionStatusText: String
    var effectiveIsSubscribed: Bool

    var isCalendarSyncToggleEnabled: Bool
    var calendarSyncEnabled: Bool

    var isThemeSettingEnabled: Bool
    var availableThemes: [AppPalette]

    var notificationPermissionEnabled: Bool
    var startNotificationEnabled: Bool
    var liveActivityEnabled: Bool
    var multipleLiveActivityEnabled: Bool
    var bufferNotificationEnabled: Bool
    var globalBufferMinutes: Int

    var isBufferSettingEnabled: Bool
    var isBufferMinutesVisible: Bool
}
