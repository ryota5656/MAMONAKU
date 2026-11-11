import Foundation

/// 予定（タイムライン配置済み + Stock）の永続化。
protocol TimelineRepository: AnyObject {
    /// 保存済みの予定を並び順どおりに返す。
    func fetchItems() -> [TimelineItem]

    /// 保存済みのルーティンを返す。
    func fetchRoutines() -> [TimelineRoutine]

    /// ルーティンの型を保存する。各日の予定は `saveItems` で別途保存する。
    func saveRoutine(_ routine: TimelineRoutine)

    /// 予定一覧を丸ごと置き換える。配列の順序が並び順になる。
    /// どの予定からも参照されなくなったルーティンは消す。
    func saveItems(_ items: [TimelineItem])

    /// 予定を 1 件削除する。標準カレンダーに同期済みのイベントも削除する。
    /// その予定がルーティンの最後の1件なら、ルーティンも消す。
    func deleteItem(id: UUID)

    /// ルーティンと、まだ紐づいている予定をまとめて削除する。
    /// 時刻を変えて外れた予定は残す。標準カレンダーに同期済みのイベントも削除する。
    func deleteRoutine(id: UUID)

    /// 標準カレンダーへのフルアクセスを確認する。未決定なら許可ダイアログを出す。
    /// - Returns: フルアクセスが許可されているか。
    func requestCalendarAccess() async -> Bool

    /// 標準カレンダー同期のオン/オフを保存し、同期の開始 / 停止に反映する。
    func setCalendarSyncEnabled(_ enabled: Bool)
}
