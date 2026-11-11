import Foundation

/// App Group の識別子と、共有 UserDefaults のキー。
/// アプリ本体と Live Activity Extension の両方から参照するため、このファイルは両ターゲットに含める。
nonisolated enum AppGroup {
    static let id = "group.sairyo.MAMONAKU"

    // MARK: - 設定

    /// 選択中のテーマ（`AppPalette.rawValue`）
    static let themeKey = "settings.theme.selected"
    static let globalBufferMinutesKey = "settings.notification.global_buffer_minutes"
    static let bufferNotificationEnabledKey = "settings.notification.buffer_enabled"
    static let startNotificationEnabledKey = "settings.notification.start_enabled"
    static let liveActivityEnabledKey = "settings.live_activity.enabled"
    static let liveActivityMultipleEnabledKey = "settings.live_activity.multiple_enabled"
    static let calendarSyncEnabledKey = "calendar_sync_enabled"

    // MARK: - 加入状態

    /// PLUS 加入状態（Live Activity Extension からも参照してスタック表示を制限する）
    static let subscriptionIsSubscribedKey = "subscription_is_subscribed"

    // MARK: - プッシュ / 認証

    static let fcmTokenKey = "push.fcm_token"
    static let liveActivityUpdateTokenKey = "push.live_activity.update_token"
    static let liveActivityPushToStartTokenKey = "push.live_activity.push_to_start_token"
    static let liveActivityDeviceIdKey = "push.live_activity.device_id"
    static let liveActivitySyncPendingKey = "push.live_activity.sync_pending"
    static let firebaseUidKey = "auth.firebase.uid"

    // MARK: - タイムライン

    /// 予定一覧の JSON ミラー。Realm が空のときの復元元として使う。
    static let timelineItemsMirrorKey = "timeline_items"

    // MARK: - 旧バージョンからの移行用

    static let legacyAppearanceKey = "settings.theme.appearance"
    static let legacyPaletteKey = "settings.theme.palette"
}
