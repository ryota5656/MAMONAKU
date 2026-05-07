import SwiftUI
import Combine
import StoreKit

struct ContentView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.requestReview) private var requestReview
    @AppStorage("onboarding.hasSeen") private var hasSeenOnboarding: Bool = false
    @AppStorage("engagement.sessionCount") private var sessionCount: Int = 0
    @AppStorage("engagement.hasShownSubscriptionPrompt") private var hasShownSubscriptionPrompt: Bool = false
    @AppStorage("engagement.hasShownReviewSatisfactionPrompt") private var hasShownReviewSatisfactionPrompt: Bool = false
    @State private var hasCountedCurrentLaunch = false
    @State private var isSubscriptionPromptPresented = false
    @State private var isReviewSatisfactionAlertPresented = false

    var body: some View {
        VStack(spacing: 0) {
            TimelineScreen()
                .background(AppColors.background(palette: themeManager.theme, environmentScheme: colorScheme))
        }
        .preferredColorScheme(themeManager.theme.preferredColorScheme)
        .onAppear {
            if !subscriptionManager.effectiveIsSubscribed, !themeManager.theme.isFreeTheme {
                themeManager.theme = .system
            }
        }
        .onChange(of: subscriptionManager.effectiveIsSubscribed) { _, isSubscribed in
            if !isSubscribed, !themeManager.theme.isFreeTheme {
                themeManager.theme = .system
            }
            handleSessionStartIfNeeded()
        }
        .onChange(of: hasSeenOnboarding) { _, hasSeen in
            guard hasSeen else { return }
            handleSessionStartIfNeeded()
        }
        .sheet(isPresented: $isSubscriptionPromptPresented) {
            SubscriptionSheetView()
                .environmentObject(subscriptionManager)
                .environmentObject(themeManager)
        }
        .alert("MAMONAKUに満足していますか？", isPresented: $isReviewSatisfactionAlertPresented) {
            Button("まだ", role: .cancel) {
            }
            Button("満足している") {
                requestReview()
            }
        } message: {
            Text("よろしければレビューで応援してください。")
        }
        .fullScreenCover(isPresented: onboardingBinding) {
            OnboardingView {
                hasSeenOnboarding = true
            }
        }
    }

    private var onboardingBinding: Binding<Bool> {
        Binding(
            get: { !hasSeenOnboarding },
            set: { isPresented in
                if !isPresented {
                    hasSeenOnboarding = true
                }
            }
        )
    }

    private func handleSessionStartIfNeeded() {
        guard hasSeenOnboarding, !hasCountedCurrentLaunch else { return }
        hasCountedCurrentLaunch = true
        sessionCount += 1
        scheduleEngagementPromptIfNeeded(for: sessionCount)
    }

    private func scheduleEngagementPromptIfNeeded(for sessionCount: Int) {
        if sessionCount == 3,
           !hasShownSubscriptionPrompt,
           !subscriptionManager.effectiveIsSubscribed {
            hasShownSubscriptionPrompt = true
            presentAfterInitialTransition {
                isSubscriptionPromptPresented = true
            }
            return
        }

        if sessionCount == 5, !hasShownReviewSatisfactionPrompt {
            hasShownReviewSatisfactionPrompt = true
            presentAfterInitialTransition {
                isReviewSatisfactionAlertPresented = true
            }
        }
    }

    private func presentAfterInitialTransition(_ action: @escaping @MainActor () -> Void) {
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            await MainActor.run {
                action()
            }
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
