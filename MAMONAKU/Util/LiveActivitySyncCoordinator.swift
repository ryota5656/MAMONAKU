import Foundation

/// Live Activity のリモート同期タイミングを制御する。
/// 予定のたびに通信せず、バックグラウンド遷移または手動更新時にまとめて送る。
enum LiveActivitySyncCoordinator {
    static let commitNotification = Notification.Name("MAMONAKU.commitLiveActivitySync")

    private static var appGroupDefaults: UserDefaults? {
        UserDefaults(suiteName: AppGroup.id)
    }

    static var isPending: Bool {
        appGroupDefaults?.bool(forKey: AppGroup.liveActivitySyncPendingKey) ?? false
    }

    static func markPending() {
        appGroupDefaults?.set(true, forKey: AppGroup.liveActivitySyncPendingKey)
    }

    static func clearPending() {
        appGroupDefaults?.set(false, forKey: AppGroup.liveActivitySyncPendingKey)
    }

    static func requestCommit() {
        NotificationCenter.default.post(name: commitNotification, object: nil)
    }

    /// アプリがフォアグラウンドに戻ったとき、Live Activity の表示が古くなっていれば更新する。
    static let foregroundRefreshNotification = Notification.Name("MAMONAKU.liveActivityForegroundRefresh")

    static func requestForegroundRefresh() {
        NotificationCenter.default.post(name: foregroundRefreshNotification, object: nil)
    }
}
