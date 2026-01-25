import Foundation
import SwiftUI
import Combine
import ActivityKit

@MainActor
final class TimelineViewModel: ObservableObject {
    private var activity: Activity<MAMONAKULiveActivityAttributes>?
    
    let hourHeight: CGFloat = 80
    let timeColumnWidth: CGFloat = 52
    let timelinePadding: CGFloat = 28
    let minuteStep: Int = 15

    @Published var items: [ScheduleItem] = []
    @Published var dropPreview: DropPreview?
    @Published var previewDuration: Int?
    @Published var dragDuration: Int?
    @Published var movePreview: DropPreview?
    @Published var movingItemID: UUID?
    @Published var resizePreview: DropPreview?
    @Published var resizingItemID: UUID?
    @Published var chipsExpanded = false
    @Published var editMode: EditMode = .inactive
    @Published var chipItemsData: [ChipItemData] = [
        .init(id: "30", title: "30分", kind: .duration(30)),
        .init(id: "60", title: "1時間", kind: .duration(60)),
        .init(id: "90", title: "90分", kind: .duration(90)),
        .init(id: "120", title: "2時間", kind: .duration(120)),
        .init(id: "15", title: "15分", kind: .duration(15)),
        .init(id: "45", title: "45分", kind: .duration(45)),
        .init(id: "1min", title: "+1分後", kind: .quickAdd)
    ]

//    private let liveActivity = TimelineViewModel()
    private let minDurationStep: Int = 15

    func addItem(duration: Int, dropY: CGFloat) {
        let start = startMinutesForDrop(duration: duration, dropY: dropY)
        let title = duration == 60 ? "1時間" : "30分"
        guard !isOverlapping(start: start, duration: duration, excluding: nil) else { return }
        items.append(ScheduleItem(title: title, startMinutes: start, durationMinutes: duration))
    }

    func addOneMinuteLaterItem() {
        let nowSeconds = secondsSinceMidnight(date: Date())
        let startMinutes = clampStart(start: (nowSeconds / 60) + 1, duration: 30)
        let title = "1分後(30分)"
        guard !isOverlapping(start: startMinutes, duration: 30, excluding: nil) else { return }
        items.append(ScheduleItem(title: title, startMinutes: startMinutes, durationMinutes: 30))
    }

    func updateMovePreview(item: ScheduleItem, deltaY: CGFloat) {
        let start = startMinutesForMove(item: item, deltaY: deltaY)
        let preview = DropPreview(title: item.title, startMinutes: start, durationMinutes: item.durationMinutes)
        movePreview = preview
        movingItemID = item.id
    }

    func commitMove(item: ScheduleItem, deltaY: CGFloat) {
        defer {
            movePreview = nil
            movingItemID = nil
        }
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        let start = startMinutesForMove(item: item, deltaY: deltaY)
        guard !isOverlapping(start: start, duration: item.durationMinutes, excluding: item.id) else { return }
        items[index].startMinutes = start
    }

    func updateResizePreview(item: ScheduleItem, deltaY: CGFloat) {
        let duration = durationForResize(item: item, deltaY: deltaY)
        resizePreview = DropPreview(title: item.title, startMinutes: item.startMinutes, durationMinutes: duration)
        resizingItemID = item.id
    }

    func commitResize(item: ScheduleItem, deltaY: CGFloat) {
        defer {
            resizePreview = nil
            resizingItemID = nil
        }
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        let duration = durationForResize(item: item, deltaY: deltaY)
        guard !isOverlapping(start: item.startMinutes, duration: duration, excluding: item.id) else { return }
        items[index].durationMinutes = duration
    }

    func deleteItem(id: UUID) {
        items.removeAll { $0.id == id }
    }

    func updatePreview(duration: Int, dropY: CGFloat) {
        let start = startMinutesForDrop(duration: duration, dropY: dropY)
        dropPreview = DropPreview(title: previewTitle(for: duration), startMinutes: start, durationMinutes: duration)
    }

    func moveChips(from: IndexSet, to: Int, visibleCount: Int) {
        let clampedTo = min(to, visibleCount)
        var visibleIndices = Array(0..<visibleCount)
        visibleIndices.move(fromOffsets: from, toOffset: clampedTo)

        var new = chipItemsData
        for (newIndex, oldIndex) in visibleIndices.enumerated() {
            new[newIndex] = chipItemsData[oldIndex]
        }
        chipItemsData = new
    }

    func minutesSinceMidnight(date: Date) -> Int {
        let cal = Calendar.current
        let comps = cal.dateComponents([.hour, .minute], from: date)
        let h = comps.hour ?? 0
        let m = comps.minute ?? 0
        return (h * 60) + m
    }

    func currentTimeText(date: Date) -> String {
        let cal = Calendar.current
        let comps = cal.dateComponents([.hour, .minute], from: date)
        let h = comps.hour ?? 0
        let m = comps.minute ?? 0
        return String(format: "%02d:%02d", h, m)
    }

    func yOffset(for startMinutes: Int) -> CGFloat {
        (CGFloat(startMinutes) / 60) * hourHeight
    }

    func heightForDuration(_ minutes: Int) -> CGFloat {
        (CGFloat(minutes) / 60) * hourHeight
    }

    func updateLiveActivity() {
        let nowSeconds = secondsSinceMidnight(date: Date())
        if let next = nextItem(afterSeconds: nowSeconds) {
            let cal = Calendar.current
            let startDate = cal.date(
                bySettingHour: next.startMinutes / 60,
                minute: next.startMinutes % 60,
                second: 0,
                of: Date()
            )
            Task {
                await startOrUpdate(nextTitle: next.title, nextStartDate: startDate)
            }
        } else {
            Task {
                await startOrUpdate(nextTitle: "予定なし", nextStartDate: nil)
            }
        }
    }

    private func startMinutesForMove(item: ScheduleItem, deltaY: CGFloat) -> Int {
        let deltaMinutes = Int((deltaY / hourHeight) * 60)
        let rawStart = item.startMinutes + deltaMinutes
        let snapped = snap(minutes: rawStart, step: minuteStep)
        return clampStart(start: snapped, duration: item.durationMinutes)
    }

    private func durationForResize(item: ScheduleItem, deltaY: CGFloat) -> Int {
        let deltaMinutes = Int((deltaY / hourHeight) * 60)
        let rawDuration = item.durationMinutes + deltaMinutes
        let snapped = snap(minutes: rawDuration, step: minDurationStep)
        return clampDuration(start: item.startMinutes, duration: snapped)
    }

    private func startMinutesForDrop(duration: Int, dropY: CGFloat) -> Int {
        let minutes = minutesFromOffset(dropY)
        let snapped = snap(minutes: minutes, step: minuteStep)
        return clampStart(start: snapped, duration: duration)
    }

    private func previewTitle(for duration: Int) -> String {
        duration == 60 ? "1時間" : "30分"
    }

    private func minutesFromOffset(_ y: CGFloat) -> Int {
        let minutes = Int((y / hourHeight) * 60)
        return max(0, min(24 * 60, minutes))
    }

    private func secondsSinceMidnight(date: Date) -> Int {
        let cal = Calendar.current
        let comps = cal.dateComponents([.hour, .minute, .second], from: date)
        let h = comps.hour ?? 0
        let m = comps.minute ?? 0
        let s = comps.second ?? 0
        return (h * 3600) + (m * 60) + s
    }

    private func nextItem(afterSeconds seconds: Int) -> ScheduleItem? {
        let startMinutes = Int(ceil(Double(seconds) / 60.0))
        return items
            .filter { $0.startMinutes >= startMinutes }
            .min(by: { $0.startMinutes < $1.startMinutes })
    }

    private func isOverlapping(start: Int, duration: Int, excluding id: UUID?) -> Bool {
        let end = start + duration
        return items.contains { item in
            if let id, item.id == id { return false }
            let itemEnd = item.startMinutes + item.durationMinutes
            return start < itemEnd && end > item.startMinutes
        }
    }

    private func snap(minutes: Int, step: Int) -> Int {
        let remainder = minutes % step
        let lower = minutes - remainder
        let upper = lower + step
        return (minutes - lower) < (upper - minutes) ? lower : upper
    }

    private func clampStart(start: Int, duration: Int) -> Int {
        let maxStart = max(0, (24 * 60) - duration)
        return max(0, min(maxStart, start))
    }

    private func clampDuration(start: Int, duration: Int) -> Int {
        let maxDuration = max(minDurationStep, (24 * 60) - start)
        return max(minDurationStep, min(maxDuration, duration))
    }
    
    func startOrUpdate(nextTitle: String, nextStartDate: Date?) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = MAMONAKULiveActivityAttributes(name: "testRoom08")
        let state = MAMONAKULiveActivityAttributes.ContentState(
            nextTitle: nextTitle,
            nextStartDate: nextStartDate
        )

        if let activity {
            await activity.update(using: state)
        } else {
            activity = try? Activity.request(
                attributes: attributes,
                contentState: state,
                pushType: nil
            )
        }
    }
}
