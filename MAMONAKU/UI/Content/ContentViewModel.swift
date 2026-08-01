import Foundation
import Combine

@MainActor
final class ContentViewModel: ObservableObject {
    struct ViewState: Equatable {
        var isSubscriptionPromptPresented: Bool = false
        var isReviewSatisfactionAlertPresented: Bool = false
    }

    enum Route: Equatable {
        case requestReview
    }

    private enum Keys {
        static let sessionCount = "engagement.sessionCount"
        static let hasShownSubscriptionPrompt = "engagement.hasShownSubscriptionPrompt"
        static let hasShownReviewSatisfactionPrompt = "engagement.hasShownReviewSatisfactionPrompt"
    }

    @Published private(set) var state: ViewState
    @Published private(set) var route: Route?

    private let userDefaults: UserDefaults
    private var hasCountedCurrentLaunch = false

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.state = ViewState(
            isSubscriptionPromptPresented: false,
            isReviewSatisfactionAlertPresented: false
        )
    }

    func handleRouteConsumed() {
        route = nil
    }

    func onAppear(
        isSubscribed: Bool,
        isCurrentThemeFree: Bool,
        applyThemeSystem: () -> Void
    ) {
        if !isSubscribed, !isCurrentThemeFree {
            applyThemeSystem()
        }
        handleSessionStartIfNeeded(isSubscribed: isSubscribed)
    }

    func onSubscriptionChanged(
        isSubscribed: Bool,
        isCurrentThemeFree: Bool,
        applyThemeSystem: () -> Void
    ) {
        if !isSubscribed, !isCurrentThemeFree {
            applyThemeSystem()
        }
        handleSessionStartIfNeeded(isSubscribed: isSubscribed)
    }

    func dismissSubscriptionPrompt() {
        state.isSubscriptionPromptPresented = false
    }

    func dismissReviewSatisfactionAlert() {
        state.isReviewSatisfactionAlertPresented = false
    }

    func userDidTapSatisfied() {
        route = .requestReview
    }

    private func handleSessionStartIfNeeded(isSubscribed: Bool?) {
        guard !hasCountedCurrentLaunch else { return }
        hasCountedCurrentLaunch = true

        let nextSessionCount = userDefaults.integer(forKey: Keys.sessionCount) + 1
        userDefaults.set(nextSessionCount, forKey: Keys.sessionCount)
        scheduleEngagementPromptIfNeeded(for: nextSessionCount, isSubscribed: isSubscribed)
    }

    private func scheduleEngagementPromptIfNeeded(for sessionCount: Int, isSubscribed: Bool?) {
        let hasShownSubscriptionPrompt = userDefaults.bool(forKey: Keys.hasShownSubscriptionPrompt)
        let hasShownReviewSatisfactionPrompt = userDefaults.bool(forKey: Keys.hasShownReviewSatisfactionPrompt)
        let isSubscribedValue = isSubscribed ?? false

        if sessionCount == 3, !hasShownSubscriptionPrompt, !isSubscribedValue {
            userDefaults.set(true, forKey: Keys.hasShownSubscriptionPrompt)
            presentAfterInitialTransition { [weak self] in
                self?.state.isSubscriptionPromptPresented = true
            }
            return
        }

        if sessionCount == 5, !hasShownReviewSatisfactionPrompt {
            userDefaults.set(true, forKey: Keys.hasShownReviewSatisfactionPrompt)
            presentAfterInitialTransition { [weak self] in
                self?.state.isReviewSatisfactionAlertPresented = true
            }
        }
    }

    private func presentAfterInitialTransition(_ action: @escaping @MainActor () -> Void) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            action()
        }
    }
}
