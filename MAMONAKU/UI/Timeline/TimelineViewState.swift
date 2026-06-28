import SwiftUI

/// タイムライン画面の UI 状態（シート・チュートリアル・ラジアルメニューなど）。Screen と 1:1。
struct TimelineViewState: Equatable {
    var sheetHeight: CGFloat = 0
    var isHeaderExpanded: Bool = true
    var isTaskSheetPresented: Bool = false
    var isDraggingTask: Bool = false
    var isSheetDropTargeted: Bool = false
    var isTaskSheetDraggable: Bool = true
    var taskSheetDetent: PresentationDetent = .fraction(0.45)
    var headerHeight: CGFloat = 0
    var isRadialMenuVisible: Bool = false
    var radialSelection: TimelineRadialAction? = nil
    var lastHapticSelection: TimelineRadialAction? = nil
    var isSettingsPresented: Bool = false
    var isDeleteButtonTargeted: Bool = false
    var isReturnToStockTargeted: Bool = false
    var isLiveActivityRefreshing: Bool = false
    var isLiveActivitySyncPending: Bool = false
    var tutorialStep: TimelineTutorialStep? = nil
    var tutorialPulse: Bool = false
}

enum TimelineTutorialStep: Equatable {
    case openTaskList
    case placeTaskAfterNow
    case confirmCountdown
    case explainLongPress
    case explainLiveActivityFromPlus
    case explainSettingsAndSubscription

    var message: String {
        switch self {
        case .openTaskList:
            return "まずは右下の＋ボタンをタップして、タスクリストを開きましょう。"
        case .placeTaskAfterNow:
            return "「はじめてのタスク」をドラッグして、現在時刻より後のタイムラインへ置いてみましょう。"
        case .confirmCountdown:
            return "残り時間が表示されることを確認できました。次へ進みましょう。"
        case .explainLongPress:
            return "タイムライン上を長押しすると、その位置に新しいアイテムをすぐ置けます。"
        case .explainLiveActivityFromPlus:
            return "編集が終わったら、＋を長押しして上にスライドするとロック画面の予定を更新できます。アプリを閉じると自動で反映されます。"
        case .explainSettingsAndSubscription:
            return "最後に日付の左側にある設定アイコンを確認しましょう。ここからテーマ変更やサブスク特典を確認でき、加入いただけると複数の予定を見やすく表示できます。"
        }
    }

    var primaryButtonTitle: String {
        switch self {
        case .explainSettingsAndSubscription:
            return "チュートリアル完了"
        default:
            return "次へ"
        }
    }
}

enum TimelineRadialAction: CaseIterable, Equatable {
    case settings
    case refreshLiveActivity

    var icon: String {
        switch self {
        case .settings: return "gearshape.fill"
        case .refreshLiveActivity: return "arrow.clockwise"
        }
    }

    var offset: CGSize {
        switch self {
        case .settings: return CGSize(width: -92, height: -56)
        case .refreshLiveActivity: return CGSize(width: 0, height: -110)
        }
    }
}
