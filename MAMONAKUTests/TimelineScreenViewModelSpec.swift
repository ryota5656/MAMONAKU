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
                    vm.timelineDidAppear()
                }

                expect(MainActor.assumeIsolated { vm.state.tutorialStep }).to(equal(.touchStock))
            }

            it("advances tutorial steps") {
                UserDefaults.standard.set(false, forKey: "tutorial.firstRun.completed")
                let vm = MainActor.assumeIsolated { makeViewModel() }

                MainActor.assumeIsolated {
                    vm.timelineDidAppear()
                    vm.timelineAdvanceTutorialStep()
                }
                expect(MainActor.assumeIsolated { vm.state.tutorialStep }).to(equal(.createTaskWithTitle))

                MainActor.assumeIsolated {
                    vm.timelineAdvanceTutorialStep()
                }
                expect(MainActor.assumeIsolated { vm.state.tutorialStep }).to(equal(.placeTaskAfterNow))

                MainActor.assumeIsolated {
                    vm.timelineAdvanceTutorialStep()
                }
                expect(MainActor.assumeIsolated { vm.state.tutorialStep }).to(equal(.confirmCountdown))

                MainActor.assumeIsolated {
                    vm.timelineAdvanceTutorialStep()
                }
                expect(MainActor.assumeIsolated { vm.state.tutorialStep }).to(equal(.confirmLiveActivity))
            }

            it("opens create sheet and advances from touchStock") {
                UserDefaults.standard.set(false, forKey: "tutorial.firstRun.completed")
                let vm = MainActor.assumeIsolated { makeViewModel() }
                MainActor.assumeIsolated {
                    vm.timelineDidAppear()
                    vm.timelineDidOpenCreateSheet()
                }

                expect(MainActor.assumeIsolated { vm.state.tutorialStep }).to(equal(.createTaskWithTitle))
            }

            it("advances to placeTaskAfterNow when a stock task is created") {
                UserDefaults.standard.set(false, forKey: "tutorial.firstRun.completed")
                let vm = MainActor.assumeIsolated { makeViewModel() }
                MainActor.assumeIsolated {
                    vm.timelineDidAppear()
                    vm.timelineDidOpenCreateSheet()
                    vm.addStockItem(title: "テスト", durationMinutes: 30)
                    vm.timelineItemsDidChange(hasPlacedTutorialTaskAfterNow: { false })
                }

                expect(MainActor.assumeIsolated { vm.state.tutorialStep }).to(equal(.placeTaskAfterNow))
            }
        }
    }
}
