import SwiftUI

/// タイムライン画面のエントリーポイント。ViewModel 連携とシート / ピークカード制御を担う。
struct TimelineScreen: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @ObservedObject var viewModel: TimelineViewModel

    var body: some View {
        TimelineScreenContent(
            state: viewModel.state,
            viewModel: viewModel,
            delegate: viewModel
        )
        .safeAreaInset(edge: .bottom, spacing: TaskSheetPresentation.peekBottomGap) {
            if showsPeekCard {
                taskSheetPeekCard
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .ignoresSafeArea(.keyboard)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: viewModel.state.taskSheetDetent)
        .onPreferenceChange(HeaderHeightKey.self) { value in
            viewModel.state.headerHeight = value
        }
        .sheet(isPresented: expandedSheetPresented, content: { taskSheetContent })
        .onChange(of: viewModel.dropPreview) { _, preview in
            viewModel.timelineDropPreviewDidChange(previewExists: preview != nil)
        }
        .onAppear {
            viewModel.timelineDidAppear(ensureTutorialTask: ensureTutorialTaskExists)
        }
        .onChange(of: viewModel.items) { _, _ in
            viewModel.timelineItemsDidChange(hasPlacedTutorialTaskAfterNow: hasPlacedTutorialTaskAfterNow)
        }
    }

    private var showsPeekCard: Bool {
        viewModel.state.taskSheetDetent == TaskSheetPresentation.peek
    }

    private var taskSheetPeekCard: some View {
        TaskListPeekCardView(
            items: viewModel.items,
            isDraggingTask: isDraggingTaskBinding,
            isSheetDropTargeted: isSheetDropTargetedBinding,
            dragItemID: $viewModel.dragItemID,
            heightForDuration: { viewModel.heightForDuration($0) },
            onExpand: expandTaskSheetFromPeek,
            onReturnToStock: { id in
                viewModel.returnItemToStock(id: id)
            }
        )
        .padding(.horizontal, 16)
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    private var taskSheetContent: some View {
        taskListSheetView
            .presentationDetents(taskSheetDetents, selection: sheetDetentBinding)
            .presentationDragIndicator(taskSheetDragIndicator)
            .presentationBackgroundInteraction(.enabled)
            .interactiveDismissDisabled(true)
    }

    private var taskListSheetView: some View {
        TaskListSheetView(
            items: viewModel.items,
            isPresented: expandedSheetPresented,
            isDraggingTask: isDraggingTaskBinding,
            isSheetDropTargeted: isSheetDropTargetedBinding,
            dragItemID: $viewModel.dragItemID,
            isSheetExpanded: $viewModel.chipsExpanded,
            sheetDetent: sheetDetentBinding,
            isSheetDraggable: isSheetDraggableBinding,
            onMove: { from, to in
                viewModel.moveTaskItems(from: from, to: to)
            },
            onAdd: { title, durationMinutes, priority in
                viewModel.addStockItem(title: title, durationMinutes: durationMinutes, priority: priority)
            },
            onDelete: { id in
                viewModel.deleteItem(id: id)
            },
            onUpdate: { id, title, durationMinutes, priority in
                viewModel.updateItemDetails(
                    id: id,
                    title: title,
                    durationMinutes: durationMinutes,
                    priority: priority
                )
            },
            onReturnToStock: { id in
                viewModel.returnItemToStock(id: id)
            },
            heightForDuration: { viewModel.heightForDuration($0) },
            onAddDebugTask: addDebugTask,
            isSubscribed: subscriptionManager.effectiveIsSubscribed
        )
    }

    private var taskSheetDetents: Set<PresentationDetent> {
        if viewModel.state.isTaskSheetDraggable {
            return TaskSheetPresentation.expandedSheetDetents
        }
        return [viewModel.state.taskSheetDetent]
    }

    private var taskSheetDragIndicator: Visibility {
        viewModel.state.isTaskSheetDraggable ? .visible : .hidden
    }

    private var isDraggingTaskBinding: Binding<Bool> {
        Binding(
            get: { viewModel.state.isDraggingTask },
            set: { viewModel.state.isDraggingTask = $0 }
        )
    }

    private var isSheetDropTargetedBinding: Binding<Bool> {
        Binding(
            get: { viewModel.state.isSheetDropTargeted },
            set: { viewModel.state.isSheetDropTargeted = $0 }
        )
    }

    private var sheetDetentBinding: Binding<PresentationDetent> {
        Binding(
            get: { viewModel.state.taskSheetDetent },
            set: { viewModel.state.taskSheetDetent = $0 }
        )
    }

    private var isSheetDraggableBinding: Binding<Bool> {
        Binding(
            get: { viewModel.state.isTaskSheetDraggable },
            set: { viewModel.state.isTaskSheetDraggable = $0 }
        )
    }

    private var expandedSheetPresented: Binding<Bool> {
        Binding(
            get: {
                viewModel.state.taskSheetDetent != TaskSheetPresentation.peek
            },
            set: { presented in
                if !presented {
                    viewModel.state.taskSheetDetent = TaskSheetPresentation.peek
                }
            }
        )
    }

    private func expandTaskSheetFromPeek() {
        viewModel.state.taskSheetDetent = TaskSheetPresentation.medium
    }

    private func addDebugTask(minutes: Int) {
        viewModel.addTestTask(
            startDate: Date().addingTimeInterval(TimeInterval(minutes * 60)),
            durationMinutes: 15
        )
    }

    private func ensureTutorialTaskExists() {
        let tutorialTitle = "はじめてのタスク"
        let hasTutorialTask = viewModel.items.contains { $0.title == tutorialTitle }
        guard !hasTutorialTask else { return }
        viewModel.addStockItem(title: tutorialTitle, durationMinutes: 30, priority: .low)
    }

    private func hasPlacedTutorialTaskAfterNow() -> Bool {
        let nowMinutes = viewModel.minutesSinceMidnight(date: Date())
        return viewModel.items.contains {
            $0.title == "はじめてのタスク" &&
            $0.dropDate != nil &&
            ($0.startMinutes ?? -1) > nowMinutes
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(SubscriptionManager())
        .environmentObject(ThemeManager())
}

#Preview("scheduleItemPreview") {
    ScheduleItemPreviewView(
        item: TimelineItem(title: "Preview", durationMinutes: 60, startMinutes: 120),
        showTimeRange: true
    )
    .frame(height: 100)
    .padding(20)
    .environmentObject(ThemeManager())
}

#Preview("timeline with items") {
    MainTabView(timelineItems: [
        TimelineItem(title: "Wake up", durationMinutes: 15, startMinutes: 17 * 60, dropDate: Date()),
        TimelineItem(title: "Workout", durationMinutes: 60, startMinutes: 2 * 60 + 45, dropDate: Date()),
        TimelineItem(title: "Breakfast", durationMinutes: 30, startMinutes: 4 * 60, dropDate: Date()),
        TimelineItem(title: "Study", durationMinutes: 120, startMinutes: 5 * 60, dropDate: Date())
    ])
    .environmentObject(SubscriptionManager())
    .environmentObject(ThemeManager())
}
