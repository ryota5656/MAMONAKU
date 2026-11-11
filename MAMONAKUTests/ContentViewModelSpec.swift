import Foundation
import Quick
import Nimble
@testable import MAMONAKU

private let sessionCountKey = "engagement.sessionCount"

/// これまでの起動回数を指定して ViewModel を作る。
@MainActor
private func makeViewModel(previousSessions: Int) -> (viewModel: ContentViewModel, defaults: UserDefaults) {
    let defaults = makeIsolatedDefaults()
    defaults.set(previousSessions, forKey: sessionCountKey)
    return (ContentViewModel(userDefaults: defaults), defaults)
}

final class ContentViewModelSpec: AsyncSpec {
    override class func spec() {
        describe("ContentViewModel") {
            it("同じ起動の中で何度表示されても、起動回数は 1 回だけ数える") { @MainActor in
                let (viewModel, defaults) = makeViewModel(previousSessions: 0)

                viewModel.onAppear(isSubscribed: false)
                viewModel.onAppear(isSubscribed: false)

                expect(defaults.integer(forKey: sessionCountKey)).to(equal(1))
            }

            it("3 回目の起動で、PLUS 未加入なら PLUS の紹介を出す") { @MainActor in
                let (viewModel, _) = makeViewModel(previousSessions: 2)

                viewModel.onAppear(isSubscribed: false)

                let isPresented = await eventually { viewModel.state.isSubscriptionPromptPresented }
                expect(isPresented).to(beTrue())
            }

            it("PLUS 加入中なら 3 回目の起動でも紹介を出さない") { @MainActor in
                let (viewModel, defaults) = makeViewModel(previousSessions: 2)

                viewModel.onAppear(isSubscribed: true)

                expect(defaults.bool(forKey: "engagement.hasShownSubscriptionPrompt")).to(beFalse())
            }

            it("5 回目の起動でレビュー依頼の確認を出す") { @MainActor in
                let (viewModel, _) = makeViewModel(previousSessions: 4)

                viewModel.onAppear(isSubscribed: false)

                let isPresented = await eventually { viewModel.state.isReviewSatisfactionAlertPresented }
                expect(isPresented).to(beTrue())
            }

            it("「満足している」を選ぶとレビュー依頼を指示し、実行後に取り下げる") { @MainActor in
                let (viewModel, _) = makeViewModel(previousSessions: 0)

                viewModel.userDidTapSatisfied()
                expect(viewModel.route).to(equal(.requestReview))

                viewModel.handleRouteConsumed()
                expect(viewModel.route).to(beNil())
            }
        }
    }
}
