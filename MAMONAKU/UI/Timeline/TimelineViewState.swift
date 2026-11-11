import Foundation

/// タイムライン画面の表示状態。Screen と 1:1。
struct TimelineViewState: Equatable {
    /// 全予定（タイムライン配置済み + Stock）。配列の順序が Stock の並び順になる。
    var items: [TimelineItem] = []
    /// 表示中の日（その日の 0 時）
    var selectedDate: Date
    /// タイムラインの寸法（ピンチによる拡大率を含む）
    var layout = TimelineLayout()

    /// 編集モード（予定の移動・リサイズ・タイトル変更ができる状態）か
    var isEditing = false
    /// ドラッグ中の予定
    var draggingItemID: UUID?
    /// ドラッグ元が分からないドロップ（ドラッグ中の予定が未設定）で、ドロップ内容から読み取った予定
    var dropItemID: UUID?
    /// ドロップ位置に表示する予定の見た目
    var dropPreview: TimelineItem?
    /// リサイズ中の予定の見た目
    var resizePreview: TimelineItem?
    /// 長押しで作成中の仮配置
    var pendingPlacement: PendingPlacement?

    /// カウントダウンヘッダーの高さ（タイムラインシートをその下から始めるために使う）
    var headerHeight: CGFloat = 0
    /// Live Activity へ反映中か
    var isLiveActivityRefreshing = false
    /// 予定の変更がまだ Live Activity に反映されていないか
    var isLiveActivitySyncPending = false
    /// 初回チュートリアルの現在のステップ（表示していなければ nil）
    var tutorialStep: TimelineTutorialStep?
    /// 現在時刻へのスクロール要求（値が変わったらスクロールする）
    var scrollToNowRequestID: UUID?
    /// 表示中のシート
    var sheet: TimelineSheet?
}

extension TimelineViewState {
    /// Stock（未配置）のタスク
    var stockItems: [TimelineItem] {
        items.filter(\.isInStock)
    }

    /// 指定日のタイムラインに並ぶ予定（終日を除く）
    func timedItems(on date: Date) -> [TimelineItem] {
        items.filter { !$0.isAllDay && $0.isPlaced(on: date) }
    }

    /// 指定日の終日予定
    func allDayItems(on date: Date) -> [TimelineItem] {
        items.filter { $0.isAllDay && $0.isPlaced(on: date) }
    }

    /// タイムラインに配置済みの予定をドラッグ中か（Stock へ戻すドロップを受け付ける条件）
    var isDraggingPlacedItem: Bool {
        guard let draggingItemID else { return false }
        return items.contains { $0.id == draggingItemID && !$0.isInStock }
    }
}

/// タイムライン画面が表示するシート。
enum TimelineSheet: Identifiable, Equatable {
    /// タスク作成
    case createTask
    /// タスク編集
    case editTask(TimelineItem)
    /// 日付選択
    case datePicker

    var id: String {
        switch self {
        case .createTask: return "createTask"
        case .editTask(let item): return "editTask-\(item.id.uuidString)"
        case .datePicker: return "datePicker"
        }
    }
}

/// 初回チュートリアルのステップ。
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
