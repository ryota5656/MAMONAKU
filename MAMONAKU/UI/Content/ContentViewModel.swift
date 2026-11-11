import Foundation
import Observation

/// アプリ全体に関わる案内（PLUS の紹介・レビュー依頼）を出すタイミングを管理する。
///
/// 起動回数を数え、3 回目に PLUS 紹介シート（未加入時のみ）、5 回目にレビュー依頼を、それぞれ一度だけ出す。
@Observable
@MainActor
final class ContentViewModel {
    struct ViewState: Equatable {
        var isSubscriptionPromptPresented = false
        var isReviewSatisfactionAlertPresented = false
    }

    enum Route: Equatable {
        case requestReview
    }

    private enum Keys {
        static let sessionCount = "engagement.sessionCount"
        static let hasShownSubscriptionPrompt = "engagement.hasShownSubscriptionPrompt"
        static let hasShownReviewSatisfactionPrompt = "engagement.hasShownReviewSatisfactionPrompt"
    }

    private static let subscriptionPromptSession = 3
    private static let reviewPromptSession = 5

    private(set) var state = ViewState()
    /// View 側で実行する副作用（レビュー依頼ダイアログ）の指示。実行後に `handleRouteConsumed` を呼ぶ。
    private(set) var route: Route?

    @ObservationIgnored private let userDefaults: UserDefaults
    @ObservationIgnored private var hasCountedCurrentLaunch = false

    init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
    }

    /// 起動を 1 回として数え、必要なら案内を出す。同じ起動の中で複数回呼ばれても 1 回しか数えない。
    func onAppear(isSubscribed: Bool) {
        guard !hasCountedCurrentLaunch else { return }
        hasCountedCurrentLaunch = true

        let sessionCount = userDefaults.integer(forKey: Keys.sessionCount) + 1
        userDefaults.set(sessionCount, forKey: Keys.sessionCount)
        presentPromptIfNeeded(sessionCount: sessionCount, isSubscribed: isSubscribed)
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

    func handleRouteConsumed() {
        route = nil
    }

    private func presentPromptIfNeeded(sessionCount: Int, isSubscribed: Bool) {
        if sessionCount == Self.subscriptionPromptSession,
           !userDefaults.bool(forKey: Keys.hasShownSubscriptionPrompt),
           !isSubscribed {
            userDefaults.set(true, forKey: Keys.hasShownSubscriptionPrompt)
            presentAfterInitialTransition { $0.isSubscriptionPromptPresented = true }
            return
        }

        if sessionCount == Self.reviewPromptSession,
           !userDefaults.bool(forKey: Keys.hasShownReviewSatisfactionPrompt) {
            userDefaults.set(true, forKey: Keys.hasShownReviewSatisfactionPrompt)
            presentAfterInitialTransition { $0.isReviewSatisfactionAlertPresented = true }
        }
    }

    /// 起動直後の画面遷移が落ち着いてから表示する。
    private func presentAfterInitialTransition(_ update: @escaping (inout ViewState) -> Void) {
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard let self else { return }
            update(&self.state)
        }
    }
}
