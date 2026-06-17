import Foundation
import Quick
import Nimble
@testable import MAMONAKU

private final class FakeTimelineRepository: TimelineRepositoryProtocol {
    private(set) var items: [TimelineItem] = []

    func fetchItems() -> [TimelineItem] { items }
    func saveItems(_ items: [TimelineItem]) { self.items = items }
    func addItem(_ item: TimelineItem) { items.append(item) }
    func updateItem(_ item: TimelineItem) {
        if let i = items.firstIndex(where: { $0.id == item.id }) {
            items[i] = item
        }
    }
    func deleteItem(id: UUID) { items.removeAll { $0.id == id } }
    func fetchNextItemSummary(referenceDate: Date) -> TimelineNextItemSummary? { nil }
    func deleteItemAndEvent(id: UUID) { deleteItem(id: id) }
    func setCalendarSyncEnabled(_ enabled: Bool) {}
}

final class SettingsViewModelSpec: QuickSpec {
    override class func spec() {
        describe("SettingsViewModel") {
            it("increments buffer minutes (1 -> 5)") {
                let repo = FakeTimelineRepository()
                let vm = SettingsViewModel(timelineRepository: repo)

                // NOTE: effectiveIsSubscribed depends on AppGroup defaults; in DEBUG, the app may already treat subscribed.
                vm.globalBufferMinutes = 1
                vm.incrementBufferMinutes()

                expect(vm.globalBufferMinutes).to(equal(5))
            }

            it("decrements buffer minutes (5 -> 1)") {
                let repo = FakeTimelineRepository()
                let vm = SettingsViewModel(timelineRepository: repo)

                vm.globalBufferMinutes = 5
                vm.decrementBufferMinutes()

                expect(vm.globalBufferMinutes).to(equal(1))
            }
        }
    }
}

