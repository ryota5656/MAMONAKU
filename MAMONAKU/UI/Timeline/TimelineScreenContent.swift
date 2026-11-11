import SwiftUI

/// タイムライン画面のレイアウト本体。ViewState を描画し、操作を Delegate へ通知する。
///
/// 上から「カウントダウン」「タイムラインシート」が重なり、画面下部に Stock カードが浮かぶ。
struct TimelineScreenContent: View {
    let state: TimelineViewState
    weak var delegate: TimelineDelegate?

    /// Stock カード下端とタブバー上端の間隔
    private static let stockCardBottomGap: CGFloat = 10

    var body: some View {
        ZStack(alignment: .top) {
            countdownSection
            // カウントダウンの下端からシートを始める
            TimelineSheetSection(state: state, delegate: delegate)
                .offset(y: state.headerHeight)
        }
        .overlay(alignment: .top) { tutorialCard }
        .overlay { liveActivityRefreshingOverlay }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // Stock カードを画面下部に常に置く（タイムラインシート自体はカードの背後まで広がる）
        .safeAreaInset(edge: .bottom, spacing: 0) { stockCard }
    }

    private var countdownSection: some View {
        TimelineCountdownSection(items: state.items)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .preference(key: HeaderHeightKey.self, value: proxy.size.height)
                }
            )
    }

    private var stockCard: some View {
        TimelineStockCard(
            stockItems: state.stockItems,
            isDraggingPlacedItem: state.isDraggingPlacedItem,
            isTutorialHighlighted: state.tutorialStep == .placeTaskAfterNow,
            onTapAdd: { delegate?.timelineDidTapAddTask() },
            onTapItem: { delegate?.timelineDidTapStockItem(id: $0) },
            onDragBegan: { delegate?.timelineDidBeginDraggingStockItem(id: $0) },
            onDragEnded: { delegate?.timelineDidEndDraggingStockItem() },
            onReorder: { fromIndex, toOffset in
                delegate?.timelineDidMoveStockItem(fromIndex: fromIndex, toOffset: toOffset)
            },
            onDropPlacedItem: { delegate?.timelineDidDropItemOnStock(id: $0) }
        )
        .padding(.horizontal, 16)
        .padding(.bottom, Self.stockCardBottomGap)
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    @ViewBuilder
    private var tutorialCard: some View {
        if let tutorialStep = state.tutorialStep {
            TimelineTutorialCard(step: tutorialStep, onSkip: {
                delegate?.timelineDidTapSkipTutorial()
            })
            .padding(.top, 14)
            .padding(.horizontal, 16)
            .animation(AppAnimation.screenTransition, value: tutorialStep)
        }
    }

    @ViewBuilder
    private var liveActivityRefreshingOverlay: some View {
        if state.isLiveActivityRefreshing {
            ZStack {
                Color.black.opacity(0.18)
                    .ignoresSafeArea()
                VStack(spacing: 10) {
                    ProgressView()
                    Text("Live Activityを更新中…")
                        .font(.footnote.weight(.semibold))
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)
                        .fill(Color(.systemBackground))
                )
            }
        }
    }
}

// MARK: - Previews / Mock

final class PreviewTimelineDelegate: TimelineDelegate {
    /// delegate は weak で保持されるため、Preview では生成済みのインスタンスを渡す
    static let shared = PreviewTimelineDelegate()

    func timelineDidSelectDate(_ date: Date) {}
    func timelineDidTapDateLabel() {}
    func timelineDidPinch(by factor: CGFloat) {}
    func timelineDidTapEmptyArea() {}
    func timelineDidBeginLongPress(on date: Date, y: CGFloat) {}
    func timelineDidMoveLongPress(on date: Date, y: CGFloat) {}
    func timelineDidEndLongPress() {}
    func timelineDidCancelLongPress() {}
    func timelineDidSubmitPendingPlacementTitle(_ title: String) {}
    func timelineDidLongPressItem(id: UUID) {}
    func timelineDidRenameItem(id: UUID, title: String) {}
    func timelineDidDragResizeHandle(itemID: UUID, translation: CGFloat) {}
    func timelineDidReleaseResizeHandle(itemID: UUID, translation: CGFloat) {}
    func timelineDidBeginDraggingItem(id: UUID) {}
    func timelineDidIdentifyDropItem(id: UUID) {}
    func timelineDidHoverDrop(itemID: UUID, on date: Date, y: CGFloat) {}
    func timelineDidExitDropArea() {}
    func timelineDidDropItem(id: UUID, on date: Date, y: CGFloat) {}
    func timelineDidFinishDrop() {}
    func timelineDidTapAddTask() {}
    func timelineDidTapStockItem(id: UUID) {}
    func timelineDidBeginDraggingStockItem(id: UUID) {}
    func timelineDidEndDraggingStockItem() {}
    func timelineDidMoveStockItem(fromIndex: Int, toOffset: Int) {}
    func timelineDidDropItemOnStock(id: UUID) {}
    func timelineDidTapSkipTutorial() {}
}

private extension TimelineViewState {
    /// プレビュー用: 今日の予定と Stock を含む状態
    static var preview: TimelineViewState {
        let today = Calendar.current.startOfDay(for: Date())
        var state = TimelineViewState(selectedDate: today)
        state.headerHeight = 80
        state.items = [
            TimelineItem(title: "Workout", durationMinutes: 60, startMinutes: 9 * 60, dropDate: today),
            TimelineItem(title: "Study", durationMinutes: 120, startMinutes: 13 * 60, dropDate: today),
            TimelineItem(title: "買い物", durationMinutes: 30),
            TimelineItem(title: "読書", durationMinutes: 45, priority: .high)
        ]
        return state
    }
}

#Preview("予定あり") {
    TimelineScreenContent(state: .preview, delegate: PreviewTimelineDelegate.shared)
}

#Preview("編集モード（ダーク）") {
    var state = TimelineViewState.preview
    state.isEditing = true
    return TimelineScreenContent(state: state, delegate: PreviewTimelineDelegate.shared)
        .background(AppTheme.dark.background)
        .environment(\.appTheme, .dark)
        .preferredColorScheme(.dark)
}

#Preview("チュートリアル") {
    var state = TimelineViewState.preview
    state.tutorialStep = .placeTaskAfterNow
    return TimelineScreenContent(state: state, delegate: PreviewTimelineDelegate.shared)
}

#Preview("Live Activity 更新中") {
    var state = TimelineViewState.preview
    state.isLiveActivityRefreshing = true
    return TimelineScreenContent(state: state, delegate: PreviewTimelineDelegate.shared)
}
