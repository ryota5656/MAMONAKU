import Foundation

/// Live Activity（ロック画面 / Dynamic Island の予定表示）への反映。
///
/// 予定を編集するたびに通信はせず、「未反映」の印だけ付けておき、
/// ユーザーが「完了」/「更新」を押したときにまとめて反映する。
@MainActor
protocol LiveActivityRepository: AnyObject {
    /// 予定の変更がまだ Live Activity に反映されていないか。
    var isSyncPending: Bool { get }

    /// 予定が変わったことを記録する。Live Activity を使わない設定のときは何もしない。
    func markSyncPending()

    /// 保存済みの予定で端末の Live Activity を更新し、サーバーにも送る。
    /// サーバーへ送れなかった場合は未反映のままにし、次の予定への切り替えを端末側で予約する。
    func commitSync() async

    /// 表示中の Live Activity の先頭の予定がすでに始まっていたら、次の予定に切り替える。
    func refreshIfOverdue() async
}
