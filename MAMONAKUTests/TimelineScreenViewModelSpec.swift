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

            it("starts tutorial on first run") {
                UserDefaults.standard.set(false, forKey: "tutorial.firstRun.completed")
                let vm = MainActor.assumeIsolated { makeViewModel() }

                MainActor.assumeIsolated {
                    vm.timelineDidAppear(ensureTutorialTask: {})
                }

                expect(MainActor.assumeIsolated { vm.state.tutorialStep }).to(equal(.openTaskList))
            }

            it("advances tutorial steps") {
                UserDefaults.standard.set(false, forKey: "tutorial.firstRun.completed")
                let vm = MainActor.assumeIsolated { makeViewModel() }

                MainActor.assumeIsolated {
                    vm.timelineDidAppear(ensureTutorialTask: {})
                    vm.timelineAdvanceTutorialStep()
                }
                expect(MainActor.assumeIsolated { vm.state.tutorialStep }).to(equal(.placeTaskAfterNow))

                MainActor.assumeIsolated {
                    vm.timelineAdvanceTutorialStep()
                }
                expect(MainActor.assumeIsolated { vm.state.tutorialStep }).to(equal(.confirmCountdown))
            }

            it("opens task sheet and advances from openTaskList") {
                UserDefaults.standard.set(false, forKey: "tutorial.firstRun.completed")
                let vm = MainActor.assumeIsolated { makeViewModel() }
                MainActor.assumeIsolated {
                    vm.timelineDidAppear(ensureTutorialTask: {})
                    vm.timelineOpenTaskSheet()
                }

                expect(MainActor.assumeIsolated { vm.state.isTaskSheetPresented }).to(beTrue())
                expect(MainActor.assumeIsolated { vm.state.tutorialStep }).to(equal(.placeTaskAfterNow))
            }
        }
    }
}
