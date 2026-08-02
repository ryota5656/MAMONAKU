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
                    // Tab 配下に置くと tabBarController を辿りやすい
                    .background {
                        TabBarReselectObserver { index in
                            handleTabReselect(index: index)
                        }
                    }
            }

            Tab(TaskSheetTab.settings.title, systemImage: TaskSheetTab.settings.icon, value: .settings) {
                SettingsScreen()
            }

            Tab(value: .action, role: .search) {
                // 選択が一瞬乗っても白く見えないよう、直前コンテンツと同じ背景色だけ置く。
                // TimelineScreen を載せると onAppear が再発火するため中身は載せない。
                AppColors.background(palette: themeManager.theme, environmentScheme: colorScheme)
                    .ignoresSafeArea()
            } label: {
                actionTabLabel
            }
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
            AnalyticsService.logScreen(screenName(for: content))
        }
        // タイムライン⇔設定などのタブ切替アニメ。action からの復元は withTransaction でアニメ無効。
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: selectedTab)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: timelineViewModel.editMode.isEditing)
        .ignoresSafeArea(.keyboard)
    }

    @ViewBuilder
    private var actionTabLabel: some View {
        if isLiveActivityRefreshing {
            ProgressView()
        } else if isTimelineEditing {
            Label("完了", systemImage: "checkmark")
        } else {
            Label("更新", systemImage: "arrow.clockwise")
        }
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

    private func handleTabReselect(index: Int) {
        // 0: timeline。設定タブ表示中の誤発火を防ぐ。
        guard index == 0 else { return }
        guard selectedTab == .timeline else { return }
        timelineViewModel.handleTimelineTabReselect()
    }

    private func handleTabSelectionChange(previous: TaskSheetTab, newValue: TaskSheetTab) {
        if newValue == .action {
            let restoreTo = previous.isContentTab ? previous : lastContentTab
            // 先にタブを戻してからアクション実行（アクションタブ画面が一瞬でも残らないようにする）
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                selectedTab = restoreTo
                timelineViewModel.state.taskSheetSelectedTab = restoreTo
            }
            performTrailingAction()
            return
        }

        lastContentTab = newValue
        timelineViewModel.state.taskSheetSelectedTab = newValue
        let screen = screenName(for: newValue)
        AnalyticsService.logScreen(screen)
        AnalyticsService.logTabSelect(screen)
    }

    private func screenName(for tab: TaskSheetTab) -> String {
        switch tab {
        case .timeline: return AnalyticsService.Screen.timeline
        case .settings: return AnalyticsService.Screen.settings
        case .action: return AnalyticsService.Screen.timeline
        }
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
        // 更新不要なら通信しない（チュートリアル最終ステップは操作体験のため許可）。
        let allowForTutorial = timelineViewModel.state.tutorialStep == .confirmComplete
        guard !isLiveActivityRefreshing, allowForTutorial || isLiveActivitySyncPending else { return }
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
