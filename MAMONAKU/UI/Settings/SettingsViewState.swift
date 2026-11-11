import Foundation

/// 設定画面の表示状態。Screen と 1:1。
struct SettingsViewState: Equatable {
    /// PLUS に加入しているか（加入時のみ使える設定の出し分けに使う）
    var isSubscribed = false
    /// 選択中の着せ替えテーマ
    var selectedTheme: AppPalette = .light

    var isCalendarSyncEnabled = false
    /// 端末の設定で通知が許可されているか
    var isNotificationPermissionGranted = false
    var isStartNotificationEnabled = true
    var isLiveActivityEnabled = true
    /// Live Activity のスタック表示（最大 3 件）
    var isLiveActivityStackEnabled = true
    var isBufferNotificationEnabled = false
    /// バッファ通知を開始の何分前に出すか
    var bufferMinutes = AppSettingsClient.defaultGlobalBufferMinutes

    var isSubscriptionSheetPresented = false
    /// DEBUG ビルドの「PLUS 加入をシミュレート」がオンか
    var isDebugSubscriptionOverridden = false
}

extension SettingsViewState {
    var subscriptionStatusText: String {
        isSubscribed ? "加入中" : "未登録"
    }

    /// テーマの選択肢。未加入でも一覧には出し、有料テーマは選べない状態で表示する。
    var availableThemes: [AppPalette] {
        AppPalette.visibleInSettings
    }

    func canSelectTheme(_ theme: AppPalette) -> Bool {
        isSubscribed || theme.isFreeTheme
    }

    /// バッファ通知がオンのときだけ、通知タイミングの行を出す。
    var isBufferMinutesVisible: Bool {
        isSubscribed && isBufferNotificationEnabled
    }

    var bufferMinutesText: String {
        "\(bufferMinutes)分前"
    }
}
