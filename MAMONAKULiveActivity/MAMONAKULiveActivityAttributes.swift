import ActivityKit
import Foundation

/// Live Activity の属性と表示内容。
/// アプリ本体（開始・更新）と Extension（描画）の両方から参照するため、このファイルは両ターゲットに含める。
/// `ContentState` の形は APNs のプッシュペイロード（Cloud Functions 側）と一致させること。
nonisolated struct MAMONAKULiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// 先頭がカウントダウン対象（プライマリ）、以降がスタック表示。
        var schedule: [ActivityTaskItem]
    }

    var name: String
}

/// Live Activity に表示する予定 1 件分。
nonisolated struct ActivityTaskItem: Codable, Hashable, Sendable {
    var nextTitle: String
    var nextStartDate: Date?
    /// プライマリスロットのカウントダウン終了時刻
    var nextEndDate: Date?
    /// カウントダウンの開始時刻（Live Activity 側ではこの固定レンジを使って更新させる）
    var countdownStartDate: Date?
    /// スタックスロットの相対時間、またはフォールバック表示用
    var remainingTimeShort: String
    var bufferMinutes: Int?
}
