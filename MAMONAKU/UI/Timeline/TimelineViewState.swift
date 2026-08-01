import SwiftUI

/// タイムライン画面の UI 状態（シート・チュートリアル・ラジアルメニューなど）。Screen と 1:1。
struct TimelineViewState: Equatable {
    var sheetHeight: CGFloat = 0
    var isHeaderExpanded: Bool = true
    var isTaskSheetPresented: Bool = true
    var isDraggingTask: Bool = false
    var isSheetDropTargeted: Bool = false
    var isTaskSheetDraggable: Bool = true
    var taskSheetDetent: PresentationDetent = TaskSheetPresentation.peek
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
    var taskSheetSelectedTab: TaskSheetTab = .timeline
}

enum TimelineTutorialStep: Equatable {
    /// Stock のプリセットを現在時刻より後へドラッグ＆ドロップ
    case placeTaskAfterNow
    /// 右下の完了（✓）で Live Activity を更新
    case confirmComplete

    var message: String {
        switch self {
        case .placeTaskAfterNow:
            return "Stock のタスクをドラッグして、現在時刻より後のタイムラインへ置いてみましょう。"
        case .confirmComplete:
            return "右下の完了（✓）をタップして、Live Activity を更新しましょう。"
        }
    }
}

enum TaskSheetPresentation {
    /// ピーク時に見えるカード部分の高さ（シート外オーバーレイ）
    static let peekCardHeight: CGFloat = 88
    /// ピーク時、カード下端とシステムタブバー上端の間隔
    static let peekBottomGap: CGFloat = 10

    /// ピーク状態を表す detent（シートの折りたたみ先としても使用）
    static let peek = PresentationDetent.height(peekCardHeight)
    static let medium = PresentationDetent.fraction(0.45)
    static let expanded = PresentationDetent.large

    /// 展開シートで使う detent（ピークはシート非表示＋オーバーレイ側。ここに含めると閉じる時に二重アニメでタイムラインが揺れる）
    static var expandedSheetDetents: Set<PresentationDetent> {
        [medium, expanded]
    }
}

/// メイン画面のタブ。`action` は `Tab(role: .search)` の右端アクション用。
enum TaskSheetTab: Hashable, CaseIterable, Equatable {
//    case later
    case timeline
//    case ai
    case settings
    /// Live Activity 更新 / 編集完了（選択せずアクションのみ発火）
    case action

    var title: String {
        switch self {
//        case .later: return "あとで"
        case .timeline: return "タイムライン"
//        case .ai: return "AI"
        case .settings: return "設定"
        case .action: return "更新"
        }
    }

    var icon: String {
        switch self {
//        case .later: return "tray.fill"
        case .timeline: return "chart.bar.fill"
//        case .ai: return "sparkles"
        case .settings: return "gearshape.fill"
        case .action: return "arrow.clockwise"
        }
    }

    var isContentTab: Bool {
        switch self {
        case .timeline, .settings: return true
        case .action: return false
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
