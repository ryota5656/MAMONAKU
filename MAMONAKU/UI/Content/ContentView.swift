import StoreKit
import SwiftUI

/// アプリのルート画面。タブシェルを表示し、アプリ全体に関わる案内（PLUS の紹介・レビュー依頼）を出す。
struct ContentView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.appTheme) private var theme
    @Environment(\.requestReview) private var requestReview

    @State private var viewModel: ContentViewModel
    private let timelineViewModel: TimelineViewModel
    private let settingsViewModel: SettingsViewModel

    init(
        viewModel: ContentViewModel,
        timelineViewModel: TimelineViewModel,
        settingsViewModel: SettingsViewModel
    ) {
        _viewModel = State(initialValue: viewModel)
        self.timelineViewModel = timelineViewModel
        self.settingsViewModel = settingsViewModel
    }

    var body: some View {
        MainTabView(timelineViewModel: timelineViewModel, settingsViewModel: settingsViewModel)
            .background(theme.background)
            .preferredColorScheme(themeManager.theme.preferredColorScheme)
            .onAppear {
                let isSubscribed = subscriptionManager.effectiveIsSubscribed
                themeManager.revertToFreeThemeIfNeeded(isSubscribed: isSubscribed)
                viewModel.onAppear(isSubscribed: isSubscribed)
            }
            .onChange(of: subscriptionManager.effectiveIsSubscribed) { _, isSubscribed in
                themeManager.revertToFreeThemeIfNeeded(isSubscribed: isSubscribed)
            }
            .sheet(isPresented: subscriptionPromptPresented) {
                SubscriptionSheetView()
            }
            .alert("MAMONAKUに満足していますか？", isPresented: reviewSatisfactionAlertPresented) {
                Button("まだ", role: .cancel) {}
                Button("満足している") {
                    viewModel.userDidTapSatisfied()
                }
            } message: {
                Text("よろしければレビューで応援してください。")
            }
            .onChange(of: viewModel.route) { _, route in
                guard let route else { return }
                switch route {
                case .requestReview:
                    requestReview()
                }
                viewModel.handleRouteConsumed()
            }
    }

    private var subscriptionPromptPresented: Binding<Bool> {
        Binding(
            get: { viewModel.state.isSubscriptionPromptPresented },
            set: { _ in viewModel.dismissSubscriptionPrompt() }
        )
    }

    private var reviewSatisfactionAlertPresented: Binding<Bool> {
        Binding(
            get: { viewModel.state.isReviewSatisfactionAlertPresented },
            set: { _ in viewModel.dismissReviewSatisfactionAlert() }
        )
    }
}
