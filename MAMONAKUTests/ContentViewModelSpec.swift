import Foundation
import Quick
import Nimble
@testable import MAMONAKU

final class ContentViewModelSpec: QuickSpec {
    override class func spec() {
        describe("ContentViewModel") {
            func makeDefaults() -> UserDefaults {
                let suite = "ContentViewModelSpec.\(UUID().uuidString)"
                let ud = UserDefaults(suiteName: suite)!
                ud.removePersistentDomain(forName: suite)
                return ud
            }

            it("shows onboarding when not seen") {
                let ud = makeDefaults()
                let vm = ContentViewModel(userDefaults: ud)
                expect(vm.state.isOnboardingPresented).to(beTrue())
            }

            it("counts a session after onboarding completion") {
                let ud = makeDefaults()
                ud.set(true, forKey: "onboarding.hasSeen")
                ud.set(0, forKey: "engagement.sessionCount")

                let vm = ContentViewModel(userDefaults: ud)
                vm.onAppear(isSubscribed: false, isCurrentThemeFree: true, applyThemeSystem: {})

                expect(ud.integer(forKey: "engagement.sessionCount")).to(equal(1))
            }

            it("presents subscription prompt on 3rd session when not subscribed") {
                let ud = makeDefaults()
                ud.set(true, forKey: "onboarding.hasSeen")
                ud.set(2, forKey: "engagement.sessionCount")
                ud.set(false, forKey: "engagement.hasShownSubscriptionPrompt")

                let vm = ContentViewModel(userDefaults: ud)
                vm.onAppear(isSubscribed: false, isCurrentThemeFree: true, applyThemeSystem: {})

                expect(vm.state.isSubscriptionPromptPresented).toEventually(beTrue(), timeout: .seconds(2))
            }
        }
    }
}

