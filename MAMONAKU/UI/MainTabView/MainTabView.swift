import SwiftUI

/// アプリ本体のタブシェル。タイムライン / 設定の Screen を切り替え、共通タブバーを表示する。
struct MainTabView: View {
    @StateObject private var timelineViewModel: TimelineViewModel
    @State private var bottomSafeAreaInset: CGFloat = 0

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
        tabContent
            .background {
                GeometryReader { geo in
                    Color.clear
                        .preference(key: MainTabBottomSafeAreaInsetKey.self, value: geo.safeAreaInsets.bottom)
                }
                .ignoresSafeArea(.keyboard)
            }
            .onPreferenceChange(MainTabBottomSafeAreaInsetKey.self) { bottomSafeAreaInset = $0 }
            .overlay(alignment: .bottom) {
                taskSheetTabBar
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: selectedTab)
            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: timelineViewModel.editMode.isEditing)
            .ignoresSafeArea(.keyboard)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .timeline:
            TimelineScreen(viewModel: timelineViewModel)
        case .settings:
            SettingsScreen()
                .padding(.bottom, TaskSheetTabBarLayout.reservedBottomInset)
        }
    }

    private var taskSheetTabBar: some View {
        TaskSheetTabBarView(
            selectedTab: selectedTabBinding,
            isTimelineEditing: timelineViewModel.editMode.isEditing,
            isLiveActivityRefreshing: timelineViewModel.state.isLiveActivityRefreshing,
            isLiveActivitySyncPending: timelineViewModel.state.isLiveActivitySyncPending,
            onCompleteEditing: completeEditing,
            onRefreshLiveActivity: refreshLiveActivity
        )
        .padding(.horizontal, 16)
        .offset(y: bottomSafeAreaInset)
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    private var selectedTab: TaskSheetTab {
        timelineViewModel.state.taskSheetSelectedTab
    }

    private var selectedTabBinding: Binding<TaskSheetTab> {
        Binding(
            get: { timelineViewModel.state.taskSheetSelectedTab },
            set: { timelineViewModel.state.taskSheetSelectedTab = $0 }
        )
    }

    private func completeEditing() {
        timelineViewModel.exitEditMode()
    }

    private func refreshLiveActivity() {
        Task { await timelineViewModel.timelineRefreshLiveActivityManually() }
    }
}

private enum MainTabBottomSafeAreaInsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
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
