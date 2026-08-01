import SwiftUI
import Combine
import StoreKit

struct ContentView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.requestReview) private var requestReview
    @StateObject private var viewModel = ContentViewModel()

    var body: some View {
        let state = viewModel.state
        VStack(spacing: 0) {
            MainTabView()
                .background(AppColors.background(palette: themeManager.theme, environmentScheme: colorScheme))
        }
        .preferredColorScheme(themeManager.theme.preferredColorScheme)
        .onAppear {
            viewModel.onAppear(
                isSubscribed: subscriptionManager.effectiveIsSubscribed,
                isCurrentThemeFree: themeManager.theme.isFreeTheme,
                applyThemeSystem: { themeManager.theme = .system }
            )
        }
        .onChange(of: subscriptionManager.effectiveIsSubscribed) { _, isSubscribed in
            viewModel.onSubscriptionChanged(
                isSubscribed: isSubscribed,
                isCurrentThemeFree: themeManager.theme.isFreeTheme,
                applyThemeSystem: { themeManager.theme = .system }
            )
        }
        .sheet(isPresented: Binding(get: { state.isSubscriptionPromptPresented }, set: { _ in viewModel.dismissSubscriptionPrompt() })) {
            SubscriptionSheetView()
                .environmentObject(subscriptionManager)
                .environmentObject(themeManager)
        }
        .alert("MAMONAKUに満足していますか？", isPresented: Binding(get: { state.isReviewSatisfactionAlertPresented }, set: { _ in viewModel.dismissReviewSatisfactionAlert() })) {
            Button("まだ", role: .cancel) {
            }
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
}

#Preview {
    ContentView()
        .environmentObject(SubscriptionManager())
        .environmentObject(ThemeManager())
}

class FontInfo: ObservableObject {
    @Published var fontNames: Array<String> = []
    
    init() {
        UIFont.familyNames.forEach {
            UIFont.fontNames(forFamilyName: $0).forEach {
                fontNames.append($0)
            }
        }
    }
}

struct FontView: View {
    @ObservedObject private var fontInfo = FontInfo()

    var body: some View {
        VStack {
            Text("フォント数:\(fontInfo.fontNames.count)")
            List {
                ForEach (0 ..< fontInfo.fontNames.count) {
                    Text("\(fontInfo.fontNames[$0])0123:")
                        .font(.custom(fontInfo.fontNames[$0], size: 16.0))
                }
            }
        }
    }
}

#Preview {
    FontView()
}
