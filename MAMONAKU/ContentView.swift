import SwiftUI
import Combine

struct ContentView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("onboarding.hasSeen") private var hasSeenOnboarding: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            TimelineScreen()
                .background(AppColors.background(palette: themeManager.theme, environmentScheme: colorScheme))
        }
        .preferredColorScheme(themeManager.theme.preferredColorScheme)
        .onAppear {
            if !subscriptionManager.effectiveIsSubscribed, themeManager.theme != .system {
                themeManager.theme = .system
            }
        }
        .onChange(of: subscriptionManager.effectiveIsSubscribed) { _, isSubscribed in
            if !isSubscribed, themeManager.theme != .system {
                themeManager.theme = .system
            }
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
