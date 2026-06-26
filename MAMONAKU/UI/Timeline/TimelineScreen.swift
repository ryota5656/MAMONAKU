import SwiftUI
import UniformTypeIdentifiers

/// タイムライン画面のエントリーポイント。ViewModel の保持とシステム制御（Sheet / ライフサイクル）のみを担う。
struct TimelineScreen: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @StateObject private var viewModel: TimelineViewModel

    init() {
        _viewModel = StateObject(wrappedValue: TimelineViewModel())
    }

    init(items: [TimelineItem]) {
        _viewModel = StateObject(
            wrappedValue: TimelineViewModel(
                initialItems: items,
                enablePolling: false
            )
        )
    }

    var body: some View {
        TimelineScreenContent(
            state: viewModel.state,
            viewModel: viewModel,
            delegate: viewModel
        )
        .onPreferenceChange(HeaderHeightKey.self) { value in
            viewModel.state.headerHeight = value
        }
        .sheet(isPresented: taskSheetPresented) { taskSheetContent }
        .sheet(isPresented: settingsPresented) {
            SettingsScreen()
        }
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

    private var taskSheetPresented: Binding<Bool> {
        Binding(
            get: { viewModel.state.isTaskSheetPresented },
            set: { viewModel.state.isTaskSheetPresented = $0 }
        )
    }

    private var settingsPresented: Binding<Bool> {
        Binding(
            get: { viewModel.state.isSettingsPresented },
            set: { viewModel.state.isSettingsPresented = $0 }
        )
    }

    private var taskSheetContent: some View {
        TaskListSheetView(
            items: viewModel.items,
            isPresented: taskSheetPresented,
            isDraggingTask: Binding(
                get: { viewModel.state.isDraggingTask },
                set: { viewModel.state.isDraggingTask = $0 }
            ),
            isSheetDropTargeted: Binding(
                get: { viewModel.state.isSheetDropTargeted },
                set: { viewModel.state.isSheetDropTargeted = $0 }
            ),
            dragItemID: $viewModel.dragItemID,
            isSheetExpanded: $viewModel.chipsExpanded,
            isSheetDraggable: Binding(
                get: { viewModel.state.isTaskSheetDraggable },
                set: { viewModel.state.isTaskSheetDraggable = $0 }
            ),
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
            heightForDuration: { viewModel.heightForDuration($0) },
            onAddDebugTask: { minutes in
                viewModel.addTestTask(
                    startDate: Date().addingTimeInterval(TimeInterval(minutes * 60)),
                    durationMinutes: 15
                )
            },
            isSubscribed: subscriptionManager.effectiveIsSubscribed
        )
        .presentationDetents(
            viewModel.state.isTaskSheetDraggable ? [.fraction(0.45), .large] : [viewModel.state.taskSheetDetent],
            selection: Binding(
                get: { viewModel.state.taskSheetDetent },
                set: { viewModel.state.taskSheetDetent = $0 }
            )
        )
        .presentationDragIndicator(viewModel.state.isTaskSheetDraggable ? .visible : .hidden)
        .presentationBackgroundInteraction(.enabled)
        .interactiveDismissDisabled(!viewModel.state.isTaskSheetDraggable)
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
    ContentView()
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
    TimelineScreen(items: [
        TimelineItem(title: "Wake up", durationMinutes: 15, startMinutes: 17 * 60, dropDate: Date()),
        TimelineItem(title: "Workout", durationMinutes: 60, startMinutes: 2 * 60 + 45, dropDate: Date()),
        TimelineItem(title: "Breakfast", durationMinutes: 30, startMinutes: 4 * 60, dropDate: Date()),
        TimelineItem(title: "Study", durationMinutes: 120, startMinutes: 5 * 60, dropDate: Date())
    ])
    .environmentObject(SubscriptionManager())
    .environmentObject(ThemeManager())
}
