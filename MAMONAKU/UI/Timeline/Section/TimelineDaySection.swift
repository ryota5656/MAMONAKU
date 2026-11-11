import SwiftUI
import UniformTypeIdentifiers

/// 1 日分のタイムライン。目盛りの上に、その日の予定と操作中のプレビューを重ねる。
///
/// - 空き領域を長押し: その時刻に予定を作成（押したままドラッグで長さを決める）
/// - 予定のドロップ: Stock からの配置、または予定の移動
struct TimelineDaySection: View {
    @Environment(\.appTheme) private var theme

    let state: TimelineViewState
    let date: Date
    let width: CGFloat
    /// 現在時刻の位置に置く、スクロール用の目印の ID
    let currentTimeAnchorID: String
    weak var delegate: TimelineDelegate?

    /// 目盛り線の分だけ空ける、予定カード右側の余白
    private static let itemTrailingInset: CGFloat = 7
    /// 予定カードに時間帯を表示する最小の高さ
    private static let timeRangeMinimumHeight: CGFloat = 30

    private var layout: TimelineLayout { state.layout }
    private var height: CGFloat { layout.dayHeight }

    /// リサイズ中のプレビューとタイトル入力カードの幅
    private var floatingCardWidth: CGFloat {
        max(80, width - TimelineLayout.horizontalPadding * 0.5)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            grid
            emptyAreaGestures
            itemCards
            dropPreview
            resizePreview
            pendingPlacement
            if Calendar.current.isDateInToday(date) {
                currentTimeIndicator
            }
        }
        .frame(width: width, height: height)
        .onDrop(of: [UTType.text], delegate: dropDelegate)
    }

    // MARK: - 下地

    @ViewBuilder
    private var grid: some View {
        TimelineGridView(width: width, layout: layout)

        // 予定カードの左に通す縦線
        Rectangle()
            .fill(theme.gridLine)
            .frame(width: 1, height: height)
            .offset(x: 7)
            .allowsHitTesting(false)
    }

    /// 空き領域のタップ（タイトル入力の取り消し）と長押し（予定の作成）。
    @ViewBuilder
    private var emptyAreaGestures: some View {
        Color.primary.opacity(0.001)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
                delegate?.timelineDidTapEmptyArea()
            }

        LongPressLocationView(
            onBegan: { y in delegate?.timelineDidBeginLongPress(on: date, y: y) },
            onChanged: { y in delegate?.timelineDidMoveLongPress(on: date, y: y) },
            onEnded: { _ in delegate?.timelineDidEndLongPress() },
            onCancelled: { delegate?.timelineDidCancelLongPress() }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // タイトル入力中は、新しい長押しを受け付けない
        .allowsHitTesting(state.pendingPlacement?.isAwaitingTitle != true)
    }

    // MARK: - 予定

    private var itemCards: some View {
        ForEach(state.timedItems(on: date)) { item in
            if let startMinutes = item.startMinutes {
                let itemHeight = layout.height(forDurationMinutes: item.durationMinutes)
                TimelineItemCard(
                    item: item,
                    isEditing: state.isEditing,
                    showsTimeRange: itemHeight > Self.timeRangeMinimumHeight,
                    onLongPress: { delegate?.timelineDidLongPressItem(id: item.id) },
                    onRename: { delegate?.timelineDidRenameItem(id: item.id, title: $0) },
                    onResizeChanged: { delegate?.timelineDidDragResizeHandle(itemID: item.id, translation: $0) },
                    onResizeEnded: { delegate?.timelineDidReleaseResizeHandle(itemID: item.id, translation: $0) },
                    onDragStart: { delegate?.timelineDidBeginDraggingItem(id: item.id) }
                )
                .padding(.trailing, Self.itemTrailingInset)
                .frame(height: itemHeight)
                .offset(y: layout.yOffset(forMinutes: startMinutes))
            }
        }
    }

    // MARK: - 操作中のプレビュー

    @ViewBuilder
    private var dropPreview: some View {
        if let preview = state.dropPreview, preview.isPlaced(on: date) {
            TimelineItemPreviewCard(item: preview, theme: theme)
                .padding(.trailing, Self.itemTrailingInset)
                .frame(height: layout.height(forDurationMinutes: preview.durationMinutes))
                .offset(y: layout.yOffset(forMinutes: preview.startMinutes ?? 0))
                .zIndex(0)
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var resizePreview: some View {
        if let preview = state.resizePreview, preview.isPlaced(on: date) {
            TimelineItemPreviewCard(item: preview, theme: theme)
                .frame(width: floatingCardWidth, height: layout.height(forDurationMinutes: preview.durationMinutes))
                .offset(y: layout.yOffset(forMinutes: preview.startMinutes ?? 0))
                .zIndex(0)
                .allowsHitTesting(false)
        }
    }

    /// 長押しで作成中の仮配置。長さを決めている間はプレビュー、指を離したらタイトル入力カードになる。
    @ViewBuilder
    private var pendingPlacement: some View {
        if let pending = state.pendingPlacement, Calendar.current.isDate(pending.date, inSameDayAs: date) {
            let pendingHeight = layout.height(forDurationMinutes: pending.durationMinutes)
            let y = layout.yOffset(forMinutes: pending.startMinutes)

            if pending.isAwaitingTitle {
                TimelinePendingPlacementCard(
                    onSubmit: { delegate?.timelineDidSubmitPendingPlacementTitle($0) }
                )
                .frame(width: floatingCardWidth, height: pendingHeight)
                .offset(y: y)
                .zIndex(10)
            } else {
                TimelineItemPreviewCard(
                    timeRangeText: DayTime.rangeText(
                        startMinutes: pending.startMinutes,
                        durationMinutes: pending.durationMinutes
                    ),
                    color: theme.itemCardColor
                )
                .padding(.trailing, Self.itemTrailingInset)
                .frame(height: pendingHeight)
                .offset(y: y)
                .zIndex(10)
                .allowsHitTesting(false)
            }
        }
    }

    // MARK: - 現在時刻

    @ViewBuilder
    private var currentTimeIndicator: some View {
        // 「現在時刻へスクロール」の行き先になる、見えない目印
        let anchorY = min(
            max(0, layout.yOffset(forMinutes: DayTime.minutesSinceMidnight(of: Date()))),
            max(0, height - 1)
        )
        VStack(spacing: 0) {
            Color.clear.frame(height: anchorY)
            Color.clear
                .frame(width: 1, height: 1)
                .id(currentTimeAnchorID)
            Spacer(minLength: 0)
        }
        .frame(width: 1, height: height, alignment: .top)
        .allowsHitTesting(false)

        TimelineCurrentTimeLineView(width: width, layout: layout)
    }

    // MARK: - ドロップ

    private var dropDelegate: TimelineDropDelegate {
        TimelineDropDelegate(
            draggingItemID: state.dropItemID ?? state.draggingItemID,
            onIdentify: { delegate?.timelineDidIdentifyDropItem(id: $0) },
            onHover: { itemID, y in delegate?.timelineDidHoverDrop(itemID: itemID, on: date, y: y) },
            onExit: { delegate?.timelineDidExitDropArea() },
            onDrop: { itemID, y in delegate?.timelineDidDropItem(id: itemID, on: date, y: y) },
            onFinish: { delegate?.timelineDidFinishDrop() }
        )
    }
}

#Preview("TimelineDaySection") {
    let today = Calendar.current.startOfDay(for: Date())
    var state = TimelineViewState(selectedDate: today)
    state.items = [
        TimelineItem(title: "Wake up", durationMinutes: 30, startMinutes: 9 * 60, dropDate: today),
        TimelineItem(title: "Workout", durationMinutes: 60, startMinutes: 10 * 60, dropDate: today)
    ]
    return ScrollView {
        TimelineDaySection(
            state: state,
            date: today,
            width: 260,
            currentTimeAnchorID: "currentTimeAnchor",
            delegate: nil
        )
        .padding()
    }
}
