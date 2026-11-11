import SwiftUI

/// 画面をまたいで揃えるアニメーション。
enum AppAnimation {
    /// タブ切替・ガイド表示など、画面レベルの切り替え
    static let screenTransition = Animation.spring(response: 0.35, dampingFraction: 0.85)
    /// 日付選択・編集モード切替など、要素の状態変化
    static let stateChange = Animation.spring(response: 0.3, dampingFraction: 0.85)
}

/// 画面をまたいで揃える角丸。
enum AppCornerRadius {
    /// 予定カード・設定カードなど標準のカード
    static let card: CGFloat = 12
}
