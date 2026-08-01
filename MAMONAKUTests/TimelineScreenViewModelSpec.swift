import Foundation
import Quick
import Nimble
@testable import MAMONAKU

final class TimelineScreenViewModelSpec: QuickSpec {
    override class func spec() {
        describe("TimelineViewModel (screen delegate)") {
            @MainActor
            func makeViewModel() -> TimelineViewModel {
                TimelineViewModel(initialItems: [], enablePolling: false)
            }

            it("starts minimal tutorial with preset stock task on first run") {
                UserDefaults.standard.set(false, forKey: "tutorial.firstRun.completed")
                let vm = MainActor.assumeIsolated { makeViewModel() }

                MainActor.assumeIsolated {
                    vm.timelineDidAppear()
                }

                expect(MainActor.assumeIsolated { vm.state.tutorialStep }).to(equal(.placeTaskAfterNow))
                expect(MainActor.assumeIsolated {
                    vm.items.contains(where: { $0.dropDate == nil && $0.title == "はじめてのタスク" })
                }).to(beTrue())
            }

            it("advances to confirmComplete after placing task after now") {
                UserDefaults.standard.set(false, forKey: "tutorial.firstRun.completed")
                let vm = MainActor.assumeIsolated { makeViewModel() }

                MainActor.assumeIsolated {
                    vm.timelineDidAppear()
                    vm.timelineItemsDidChange(hasPlacedTutorialTaskAfterNow: { true })
                }

                expect(MainActor.assumeIsolated { vm.state.tutorialStep }).to(equal(.confirmComplete))
            }

            it("skips tutorial with あとで") {
                UserDefaults.standard.set(false, forKey: "tutorial.firstRun.completed")
                let vm = MainActor.assumeIsolated { makeViewModel() }

                MainActor.assumeIsolated {
                    vm.timelineDidAppear()
                    vm.timelineSkipTutorial()
                }

                expect(MainActor.assumeIsolated { vm.state.tutorialStep }).toEventually(beNil(), timeout: .seconds(2))
                expect(UserDefaults.standard.bool(forKey: "tutorial.firstRun.completed")).toEventually(beTrue(), timeout: .seconds(2))
            }
        }
    }
}
