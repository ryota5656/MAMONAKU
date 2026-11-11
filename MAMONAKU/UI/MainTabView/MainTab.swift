import Foundation

/// タブバーの項目。
enum MainTab: Hashable {
    case timeline
    case settings
    /// 右端のボタン（編集完了 / Live Activity 更新）。画面は持たず、タップされたら処理だけ行って元のタブへ戻す。
    case action

    var title: String {
        switch self {
        case .timeline: return "タイムライン"
        case .settings: return "設定"
        case .action: return "更新"
        }
    }

    var icon: String {
        switch self {
        case .timeline: return "chart.bar.fill"
        case .settings: return "gearshape.fill"
        case .action: return "arrow.clockwise"
        }
    }

    /// 画面を持つタブか
    var isContentTab: Bool {
        self != .action
    }

    /// 計測に使う画面名
    var analyticsScreenName: String {
        switch self {
        case .timeline, .action: return AnalyticsClient.Screen.timeline
        case .settings: return AnalyticsClient.Screen.settings
        }
    }
}
