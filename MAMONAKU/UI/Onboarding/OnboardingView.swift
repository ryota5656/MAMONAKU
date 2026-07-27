import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    

    @State private var currentPage: Int = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            title: "ようこそ MAMONAKU へ",
            message: "次の予定までの時間を、ひと目で把握できます。",
            icon: .asset("onBoarding1")
        ),
        OnboardingPage(
            title: "タスクを簡単に配置",
            message: "Stockからドラッグして、1日の流れを直感的に作れます。",
            icon: .symbol("hand.draw")
        ),
        OnboardingPage(
            title: "通知で次の行動をサポート",
            message: "バッファ通知とLive Activityで、次の予定を逃しません。",
            icon: .symbol("bell.badge")
        )
    ]

    var body: some View {
        let background = AppColors.background(palette: themeManager.theme, environmentScheme: colorScheme)
        let strongAccent = AppColors.strongAccent(palette: themeManager.theme, environmentScheme: colorScheme)
        let textPrimary = AppColors.textPrimary(palette: themeManager.theme, environmentScheme: colorScheme)
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    VStack(spacing: 22) {
                        Spacer(minLength: 20)
                        switch page.icon {
                        case .symbol(let symbolName):
                            Image(systemName: symbolName)
                                .font(.system(size: 64, weight: .semibold))
                                .foregroundStyle(strongAccent)
                        case .asset(let assetName):
                            Image(assetName)
                                .resizable()
                                .renderingMode(.template)
                                .scaledToFit()
                                .frame(width: 164)
                                .foregroundStyle(strongAccent)
                        }
                        VStack(spacing: 10) {
                            Text(page.title)
                                .font(.title2.weight(.bold))
                                .multilineTextAlignment(.center)
                            Text(page.message)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                        Spacer()
                    }
                    .tag(index)
                    .padding(.horizontal, 24)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            HStack(spacing: 12) {
                if currentPage > 0 {
                    Button("戻る") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            currentPage -= 1
                        }
                    }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(textPrimary)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                }

                Spacer()

                Button(currentPage == pages.count - 1 ? "はじめる" : "次へ") {
                    if currentPage == pages.count - 1 {
                        onFinish()
                    } else {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            currentPage += 1
                        }
                    }
                }
                .font(.body.weight(.bold))
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .foregroundStyle(.white)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(strongAccent)
                )
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .background(background)
        .interactiveDismissDisabled(true)
        .onAppear {
            AnalyticsService.logScreen(AnalyticsService.Screen.onboarding)
        }
    }
}

private struct OnboardingPage {
    let title: String
    let message: String
    let icon: OnboardingPageIcon
}

private enum OnboardingPageIcon {
    case symbol(String)
    case asset(String)
}

#Preview {
    OnboardingView(onFinish: {})
        .environmentObject(ThemeManager())
}
