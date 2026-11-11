import CoreGraphics
import Foundation

/// タイムライン画面（`TimelineScreenContent`）で起きたユーザー操作の通知先。
///
/// 位置を渡す操作の `y` は、その日のタイムライン上端からの距離（pt）。
@MainActor
protocol TimelineDelegate: AnyObject {
    // MARK: 日付・表示

    func timelineDidSelectDate(_ date: Date)
    func timelineDidTapDateLabel()
    /// ピンチで拡大・縮小した。`factor` は直前からの倍率。
    func timelineDidPinch(by factor: CGFloat)

    // MARK: 空き領域（長押しで予定を作成）

    func timelineDidTapEmptyArea()
    func timelineDidBeginLongPress(on date: Date, y: CGFloat)
    func timelineDidMoveLongPress(on date: Date, y: CGFloat)
    func timelineDidEndLongPress()
    func timelineDidCancelLongPress()
    func timelineDidSubmitPendingPlacementTitle(_ title: String)

    // MARK: タイムライン上の予定

    func timelineDidLongPressItem(id: UUID)
    func timelineDidRenameItem(id: UUID, title: String)
    /// リサイズハンドルをドラッグ中。`translation` はドラッグ開始からの縦移動量（pt）。
    func timelineDidDragResizeHandle(itemID: UUID, translation: CGFloat)
    func timelineDidReleaseResizeHandle(itemID: UUID, translation: CGFloat)
    func timelineDidBeginDraggingItem(id: UUID)

    // MARK: タイムラインへのドロップ

    /// ドロップ内容から、ドラッグされている予定が分かった。
    func timelineDidIdentifyDropItem(id: UUID)
    func timelineDidHoverDrop(itemID: UUID, on date: Date, y: CGFloat)
    func timelineDidExitDropArea()
    func timelineDidDropItem(id: UUID, on date: Date, y: CGFloat)
    /// ドロップ操作が終わった（成否によらず、指を離した時点で呼ばれる）。
    func timelineDidFinishDrop()

    // MARK: Stock

    func timelineDidTapAddTask()
    func timelineDidTapStockItem(id: UUID)
    func timelineDidBeginDraggingStockItem(id: UUID)
    func timelineDidEndDraggingStockItem()
    /// Stock 内で並べ替えた。`toOffset` は動かす前の並びで数えた挿入先。
    func timelineDidMoveStockItem(fromIndex: Int, toOffset: Int)
    /// タイムライン上の予定が Stock にドロップされた。
    func timelineDidDropItemOnStock(id: UUID)

    // MARK: チュートリアル

    func timelineDidTapSkipTutorial()
}
