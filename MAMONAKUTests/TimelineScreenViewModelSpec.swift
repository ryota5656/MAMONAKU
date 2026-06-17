import Foundation
import Quick
import Nimble
@testable import MAMONAKU

final class TimelineScreenViewModelSpec: QuickSpec {
    override class func spec() {
        describe("TimelineScreenViewModel") {
            func makeDefaults() -> UserDefaults {
                let suite = "TimelineScreenViewModelSpec.\(UUID().uuidString)"
                let ud = UserDefaults(suiteName: suite)!
                ud.removePersistentDomain(forName: suite)
                return ud
            }

            it("starts tutorial on first run") {
                let ud = makeDefaults()
                ud.set(false, forKey: "tutorial.firstRun.completed")
                let vm = TimelineScreenViewModel(userDefaults: ud, isRunningInPreview: false)

                vm.onAppear(ensureTutorialTask: {})

                expect(vm.state.tutorialStep).to(equal(.openTaskList))
            }

            it("advances tutorial steps") {
                let ud = makeDefaults()
                ud.set(false, forKey: "tutorial.firstRun.completed")
                let vm = TimelineScreenViewModel(userDefaults: ud, isRunningInPreview: false)

                vm.onAppear(ensureTutorialTask: {})
                vm.advanceTutorialStep()
                expect(vm.state.tutorialStep).to(equal(.placeTaskAfterNow))

                vm.advanceTutorialStep()
                expect(vm.state.tutorialStep).to(equal(.confirmCountdown))
            }

            it("opens task sheet and advances from openTaskList") {
                let ud = makeDefaults()
                ud.set(false, forKey: "tutorial.firstRun.completed")
                let vm = TimelineScreenViewModel(userDefaults: ud, isRunningInPreview: false)
                vm.onAppear(ensureTutorialTask: {})

                vm.openTaskSheet()

                expect(vm.state.isTaskSheetPresented).to(beTrue())
                expect(vm.state.tutorialStep).to(equal(.placeTaskAfterNow))
            }
        }
    }
}

