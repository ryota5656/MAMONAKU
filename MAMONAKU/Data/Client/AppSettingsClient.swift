import Foundation

/// App Group の UserDefaults に保存する設定値・加入状態への型付きアクセス。
///
/// キー名・既定値・値の範囲をここに集約し、画面 / 通知 / Live Activity / カレンダー同期が
/// 同じ解釈で値を読めるようにする。テストでは専用 suite の `UserDefaults` を渡して隔離する。
/// カレンダー同期のバックグラウンドキューからも読むため actor に隔離しない（UserDefaults はスレッドセーフ）。
nonisolated final class AppSettingsClient: @unchecked Sendable {
    static let defaultGlobalBufferMinutes = 10
    static let bufferMinutesRange = 1...120

    /// 同じ suite を使う他のインフラ（リポジトリのミラー保存など）と共有する。
    let defaults: UserDefaults

    init(defaults: UserDefaults = UserDefaults(suiteName: AppGroup.id) ?? .standard) {
        self.defaults = defaults
    }

    // MARK: - 加入状態

    /// PLUS 加入状態（DEBUG のオーバーライドを加味した値を `SubscriptionManager` が書き込む）。
    var isSubscribed: Bool {
        get { bool(AppGroup.subscriptionIsSubscribedKey, default: false) }
        set { defaults.set(newValue, forKey: AppGroup.subscriptionIsSubscribedKey) }
    }

    // MARK: - カレンダー同期

    /// ユーザーが選んだ同期オン/オフ。
    var isCalendarSyncPreferred: Bool {
        get { bool(AppGroup.calendarSyncEnabledKey, default: false) }
        set { defaults.set(newValue, forKey: AppGroup.calendarSyncEnabledKey) }
    }

    /// 標準カレンダー同期は PLUS 加入時のみ有効。
    var isCalendarSyncEnabled: Bool {
        isCalendarSyncPreferred && isSubscribed
    }

    // MARK: - 通知

    var isStartNotificationEnabled: Bool {
        get { bool(AppGroup.startNotificationEnabledKey, default: true) }
        set { defaults.set(newValue, forKey: AppGroup.startNotificationEnabledKey) }
    }

    /// ユーザーが選んだバッファ通知オン/オフ。
    var isBufferNotificationPreferred: Bool {
        get { bool(AppGroup.bufferNotificationEnabledKey, default: false) }
        set { defaults.set(newValue, forKey: AppGroup.bufferNotificationEnabledKey) }
    }

    /// バッファ通知は PLUS 加入時のみ有効。
    var isBufferNotificationEnabled: Bool {
        isBufferNotificationPreferred && isSubscribed
    }

    /// 全タスク共通のバッファ分。常に `bufferMinutesRange` に収めて返す。
    var globalBufferMinutes: Int {
        get {
            let stored = defaults.object(forKey: AppGroup.globalBufferMinutesKey) as? Int
            return Self.clampBufferMinutes(stored ?? Self.defaultGlobalBufferMinutes)
        }
        set { defaults.set(Self.clampBufferMinutes(newValue), forKey: AppGroup.globalBufferMinutesKey) }
    }

    /// 予定に適用するバッファ分。バッファ通知が無効なら nil。
    /// - Parameter itemOverride: 予定個別のバッファ分（未設定なら全体設定を使う）。
    func effectiveBufferMinutes(itemOverride: Int?) -> Int? {
        guard isBufferNotificationEnabled else { return nil }
        return Self.clampBufferMinutes(itemOverride ?? globalBufferMinutes)
    }

    static func clampBufferMinutes(_ value: Int) -> Int {
        min(max(value, bufferMinutesRange.lowerBound), bufferMinutesRange.upperBound)
    }

    // MARK: - Live Activity

    var isLiveActivityEnabled: Bool {
        get { bool(AppGroup.liveActivityEnabledKey, default: true) }
        set { defaults.set(newValue, forKey: AppGroup.liveActivityEnabledKey) }
    }

    /// ユーザーが選んだスタック表示（最大 3 件）オン/オフ。
    var isLiveActivityStackPreferred: Bool {
        get { bool(AppGroup.liveActivityMultipleEnabledKey, default: true) }
        set { defaults.set(newValue, forKey: AppGroup.liveActivityMultipleEnabledKey) }
    }

    /// 無料: 1 件。PLUS かつスタック表示オン: 最大 3 件。PLUS でもオフなら 1 件。
    var liveActivityPlanScope: LiveActivityScheduleBuilder.PlanScope {
        isSubscribed && isLiveActivityStackPreferred ? .plus : .free
    }

    /// 予定の変更がまだ Live Activity / クラウドへ反映されていないか。
    var isLiveActivitySyncPending: Bool {
        get { bool(AppGroup.liveActivitySyncPendingKey, default: false) }
        set { defaults.set(newValue, forKey: AppGroup.liveActivitySyncPendingKey) }
    }

    // MARK: - テーマ

    /// 選択中テーマの生値（`AppPalette.rawValue`）。未保存なら nil。
    var themeRawValue: String? {
        get { defaults.string(forKey: AppGroup.themeKey) }
        set { defaults.set(newValue, forKey: AppGroup.themeKey) }
    }

    /// 旧バージョンの外観設定（"light" / "dark" / "system"）。移行時のみ参照する。
    var legacyAppearanceRawValue: String? {
        defaults.string(forKey: AppGroup.legacyAppearanceKey)
    }

    /// 旧バージョンの配色設定（"minimal" / "elegant" / "pastel"）。移行時のみ参照する。
    var legacyPaletteRawValue: String? {
        defaults.string(forKey: AppGroup.legacyPaletteKey)
    }

    // MARK: - Private

    private func bool(_ key: String, default defaultValue: Bool) -> Bool {
        defaults.object(forKey: key) as? Bool ?? defaultValue
    }
}
