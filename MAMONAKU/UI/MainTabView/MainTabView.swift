import SwiftUI

/// アプリ本体のタブシェル。タイムライン / 設定を切り替える。
///
/// タブバー右端には `Tab(role: .search)` の位置を借りてボタンを置く
/// （タイムライン編集中は「完了」、それ以外は「更新」）。
struct MainTabView: View {
    @Environment(\.appTheme) private var theme

    let timelineViewModel: TimelineViewModel
    let settingsViewModel: SettingsViewModel

    /// TabView の選択。`.action` が選ばれたら、すぐ直前のタブへ戻す。
    @State private var selectedTab: MainTab = .timeline
    @State private var lastContentTab: MainTab = .timeline

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(MainTab.timeline.title, systemImage: MainTab.timeline.icon, value: MainTab.timeline) {
                TimelineScreen(viewModel: timelineViewModel)
                    // Tab 配下に置くと tabBarController を辿りやすい
                    .background {
                        TabBarReselectObserver { index in
                            handleTabReselect(index: index)
                        }
                    }
            }

            Tab(MainTab.settings.title, systemImage: MainTab.settings.icon, value: MainTab.settings) {
                SettingsScreen(viewModel: settingsViewModel)
            }

            Tab(value: MainTab.action, role: .search) {
                // 選択が一瞬乗っても白く見えないよう、直前コンテンツと同じ背景色だけ置く。
                // TimelineScreen を載せると onAppear が再発火するため中身は載せない。
                theme.background
                    .ignoresSafeArea()
            } label: {
                actionTabLabel
            }
        }
        .tint(theme.strongAccent)
        .onChange(of: selectedTab) { previous, newValue in
            handleTabSelectionChange(previous: previous, newValue: newValue)
        }
        .onAppear {
            AnalyticsClient.logScreen(lastContentTab.analyticsScreenName)
        }
        // タイムライン⇔設定などのタブ切替アニメ。action からの復元は withTransaction でアニメ無効。
        .animation(AppAnimation.screenTransition, value: selectedTab)
        .animation(AppAnimation.stateChange, value: timelineViewModel.state.isEditing)
        .ignoresSafeArea(.keyboard)
    }

    @ViewBuilder
    private var actionTabLabel: some View {
        if timelineViewModel.state.isLiveActivityRefreshing {
            ProgressView()
        } else if timelineViewModel.state.isEditing {
            Label("完了", systemImage: "checkmark")
        } else {
            Label(MainTab.action.title, systemImage: MainTab.action.icon)
        }
    }

    private func handleTabReselect(index: Int) {
        // 0: timeline。設定タブ表示中の誤発火を防ぐ。
        guard index == 0, selectedTab == .timeline else { return }
        timelineViewModel.timelineTabDidReselect()
    }

    private func handleTabSelectionChange(previous: MainTab, newValue: MainTab) {
        guard newValue == .action else {
            lastContentTab = newValue
            AnalyticsClient.logScreen(newValue.analyticsScreenName)
            AnalyticsClient.logTabSelect(newValue.analyticsScreenName)
            return
        }

        // 先にタブを戻してからアクション実行（アクションタブ画面が一瞬でも残らないようにする）
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            selectedTab = previous.isContentTab ? previous : lastContentTab
        }
        Task { await timelineViewModel.trailingActionDidTap() }
    }
}
