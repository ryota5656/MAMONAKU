import SwiftUI

/// アプリ本体のタブシェル。タイムライン / 設定を切り替え、右端は `Tab(role: .search)` でアクションを置く。
struct MainTabView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @StateObject private var timelineViewModel: TimelineViewModel
    /// TabView の選択。`.action` はタップ検知用で、すぐ直前タブへ戻す。
    @State private var selectedTab: TaskSheetTab = .timeline
    @State private var lastContentTab: TaskSheetTab = .timeline

    init() {
        _timelineViewModel = StateObject(wrappedValue: TimelineViewModel())
    }

    init(timelineItems: [TimelineItem]) {
        _timelineViewModel = StateObject(
            wrappedValue: TimelineViewModel(
                initialItems: timelineItems,
                enablePolling: false
            )
        )
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(TaskSheetTab.timeline.title, systemImage: TaskSheetTab.timeline.icon, value: .timeline) {
                TimelineScreen(viewModel: timelineViewModel)
            }

            Tab(TaskSheetTab.settings.title, systemImage: TaskSheetTab.settings.icon, value: .settings) {
                SettingsScreen()
            }

            Tab(value: .action, role: .search) {
                // 中身は触らず、onChange で直前タブへ戻す（Color.clear は白画面に見える）。
                // TimelineScreen を載せると onAppear が再発火するため背景のみにする。
                AppColors.background(palette: themeManager.theme, environmentScheme: colorScheme)
                    .ignoresSafeArea()
            } label: {
                actionTabLabel
            }
            .badge(actionTabBadgeCount)
        }
        .tint(AppColors.strongAccent(palette: themeManager.theme, environmentScheme: colorScheme))
        .onChange(of: selectedTab) { previous, newValue in
            handleTabSelectionChange(previous: previous, newValue: newValue)
        }
        .onChange(of: timelineViewModel.state.taskSheetSelectedTab) { _, newValue in
            syncSelectionFromViewModel(newValue)
        }
        .onAppear {
            let initial = timelineViewModel.state.taskSheetSelectedTab
            let content = initial.isContentTab ? initial : .timeline
            selectedTab = content
            lastContentTab = content
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: selectedTab)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: timelineViewModel.editMode.isEditing)
        .ignoresSafeArea(.keyboard)
    }

    @ViewBuilder
    private var actionTabLabel: some View {
        if isTimelineEditing {
            Label("完了", systemImage: "checkmark")
        } else if isLiveActivityRefreshing {
            ProgressView()
        } else {
            Label("更新", systemImage: "arrow.clockwise")
        }
    }

    private var actionTabBadgeCount: Int {
        guard !isTimelineEditing,
              !isLiveActivityRefreshing,
              isLiveActivitySyncPending else { return 0 }
        return 1
    }

    private var isTimelineEditing: Bool {
        timelineViewModel.editMode.isEditing
    }

    private var isLiveActivityRefreshing: Bool {
        timelineViewModel.state.isLiveActivityRefreshing
    }

    private var isLiveActivitySyncPending: Bool {
        timelineViewModel.state.isLiveActivitySyncPending
    }

    private func handleTabSelectionChange(previous: TaskSheetTab, newValue: TaskSheetTab) {
        if newValue == .action {
            let restoreTo = previous.isContentTab ? previous : lastContentTab
            performTrailingAction()
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                selectedTab = restoreTo
                timelineViewModel.state.taskSheetSelectedTab = restoreTo
            }
            return
        }

        lastContentTab = newValue
        timelineViewModel.state.taskSheetSelectedTab = newValue
    }

    private func syncSelectionFromViewModel(_ newValue: TaskSheetTab) {
        guard newValue.isContentTab else { return }
        guard selectedTab != newValue else { return }
        selectedTab = newValue
        lastContentTab = newValue
    }

    private func performTrailingAction() {
        if isTimelineEditing {
            completeEditing()
            return
        }
        guard !isLiveActivityRefreshing else { return }
        refreshLiveActivity()
    }

    private func completeEditing() {
        Task { await timelineViewModel.completeEditingAndSyncLiveActivity() }
    }

    private func refreshLiveActivity() {
        Task { await timelineViewModel.timelineRefreshLiveActivityManually() }
    }
}

#Preview {
    MainTabView()
        .environmentObject(SubscriptionManager())
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
