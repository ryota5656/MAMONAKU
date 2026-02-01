import Foundation
import SwiftUI
import Combine
import ActivityKit

@MainActor
class TimelineViewModel: ObservableObject {
    private let repository: TimelineRepositoryProtocol
    
    let hourHeight: CGFloat = 80
    let timeColumnWidth: CGFloat = 52
    let timelinePadding: CGFloat = 28
    let minuteStep: Int = 15

    @Published var items: [TimelineItem] = []
    @Published var dropPreview: TimelineItem?
    @Published var previewItemID: UUID?
    @Published var dragItemID: UUID?
    @Published var movePreview: TimelineItem?
    @Published var movingItemID: UUID?
    @Published var resizePreview: TimelineItem?
    @Published var resizingItemID: UUID?
    @Published var chipsExpanded = false
    @Published var editMode: EditMode = .inactive
    @Published var selectedDate = Date()
    @Published var isTwoDayView = false
    @Published var zoomScale: CGFloat = 1.0

    private let minDurationStep: Int = 15
    private var activity: Activity<MAMONAKULiveActivityAttributes>?

    init(repository: TimelineRepositoryProtocol = TimelineRepository()) {
        self.repository = repository
        let stored = repository.fetchItems()
        if stored.isEmpty {
            repository.saveItems(items)
        } else {
            items = stored
        }
    }

    func addItem(item: TimelineItem, dropY: CGFloat, on date: Date) {
        let start = startMinutesForDrop(duration: item.durationMinutes, dropY: dropY)
        guard !isOverlapping(start: start, duration: item.durationMinutes, excluding: item.id, on: date) else { return }
        let updated = TimelineItem(
            id: item.id,
            title: item.title,
            durationMinutes: item.durationMinutes,
            startMinutes: start,
            dropDate: selectedDropDate(for: date)
        )
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = updated
        } else {
            items.append(updated)
        }
        persistItems()
    }

    func addOneMinuteLaterItem() {
        let nowSeconds = secondsSinceMidnight(date: Date())
        let startMinutes = clampStart(start: (nowSeconds / 60) + 1, duration: 30)
        let title = "1分後(30分)"
        guard !isOverlapping(start: startMinutes, duration: 30, excluding: nil, on: selectedDate) else { return }
        items.append(
            TimelineItem(
                title: title,
                durationMinutes: 30,
                startMinutes: startMinutes,
                dropDate: selectedDropDate(for: selectedDate)
            )
        )
        persistItems()
    }

    func addStockItem(title: String, durationMinutes: Int) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        items.append(
            TimelineItem(
                title: trimmedTitle,
                durationMinutes: durationMinutes
            )
        )
        persistItems()
    }

    func updateMovePreview(item: TimelineItem, deltaY: CGFloat) {
        guard let start = startMinutesForMove(item: item, deltaY: deltaY) else { return }
        let baseDate = item.dropDate ?? selectedDate
        let preview = TimelineItem(
            title: item.title,
            durationMinutes: item.durationMinutes,
            startMinutes: start,
            dropDate: selectedDropDate(for: baseDate)
        )
        movePreview = preview
        movingItemID = item.id
    }

    func commitMove(item: TimelineItem, deltaY: CGFloat) {
        defer {
            movePreview = nil
            movingItemID = nil
        }
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        guard let start = startMinutesForMove(item: item, deltaY: deltaY) else { return }
        let baseDate = item.dropDate ?? selectedDate
        guard !isOverlapping(start: start, duration: item.durationMinutes, excluding: item.id, on: baseDate) else { return }
        items[index].startMinutes = start
        items[index].dropDate = selectedDropDate(for: baseDate)
        persistItems()
    }

    func updateResizePreview(item: TimelineItem, deltaY: CGFloat) {
        guard let startMinutes = item.startMinutes else { return }
        let duration = durationForResize(item: item, deltaY: deltaY)
        let baseDate = item.dropDate ?? selectedDate
        resizePreview = TimelineItem(
            title: item.title,
            durationMinutes: duration,
            startMinutes: startMinutes,
            dropDate: selectedDropDate(for: baseDate)
        )
        resizingItemID = item.id
    }

    func commitResize(item: TimelineItem, deltaY: CGFloat) {
        defer {
            resizePreview = nil
            resizingItemID = nil
        }
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        let duration = durationForResize(item: item, deltaY: deltaY)
        guard let startMinutes = item.startMinutes else { return }
        let baseDate = item.dropDate ?? selectedDate
        guard !isOverlapping(start: startMinutes, duration: duration, excluding: item.id, on: baseDate) else { return }
        items[index].durationMinutes = duration
        persistItems()
    }

    func deleteItem(id: UUID) {
        items.removeAll { $0.id == id }
        persistItems()
    }

    func updatePreview(item: TimelineItem, dropY: CGFloat, on date: Date) {
        let start = startMinutesForDrop(duration: item.durationMinutes, dropY: dropY)
        dropPreview = TimelineItem(
            id: item.id,
            title: item.title,
            durationMinutes: item.durationMinutes,
            startMinutes: start,
            dropDate: selectedDropDate(for: date)
        )
    }

    func moveChips(from: IndexSet, to: Int, visibleCount: Int) {
        let clampedTo = min(to, visibleCount)
        var visibleIndices = Array(0..<visibleCount)
        visibleIndices.move(fromOffsets: from, toOffset: clampedTo)

        var new = items
        for (newIndex, oldIndex) in visibleIndices.enumerated() {
            new[newIndex] = items[oldIndex]
        }
        items = new
        persistItems()
    }

    var itemsForSelectedDate: [TimelineItem] {
        items(for: selectedDate)
    }

    func items(for date: Date) -> [TimelineItem] {
        items.filter { item in
            guard let dropDate = item.dropDate else { return false }
            return Calendar.current.isDate(dropDate, inSameDayAs: date)
        }
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
        (CGFloat(startMinutes) / 60) * hourHeight * zoomScale
    }

    func heightForDuration(_ minutes: Int) -> CGFloat {
        (CGFloat(minutes) / 60) * hourHeight * zoomScale
    }

    func updateLiveActivity() {
        let nowSeconds = secondsSinceMidnight(date: Date())
        if let next = nextItem(afterSeconds: nowSeconds) {
            let cal = Calendar.current
            let startDate = cal.date(
                bySettingHour: (next.startMinutes ?? 0) / 60,
                minute: (next.startMinutes ?? 0) % 60,
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

    private func startMinutesForMove(item: TimelineItem, deltaY: CGFloat) -> Int? {
        guard let startMinutes = item.startMinutes else { return nil }
        let deltaMinutes = Int((deltaY / (hourHeight * zoomScale)) * 60)
        let rawStart = startMinutes + deltaMinutes
        let snapped = snap(minutes: rawStart, step: minuteStep)
        return clampStart(start: snapped, duration: item.durationMinutes)
    }

    private func durationForResize(item: TimelineItem, deltaY: CGFloat) -> Int {
        let deltaMinutes = Int((deltaY / (hourHeight * zoomScale)) * 60)
        let rawDuration = item.durationMinutes + deltaMinutes
        let snapped = snap(minutes: rawDuration, step: minDurationStep)
        let startMinutes = item.startMinutes ?? 0
        return clampDuration(start: startMinutes, duration: snapped)
    }

    private func startMinutesForDrop(duration: Int, dropY: CGFloat) -> Int {
        let minutes = minutesFromOffset(dropY)
        let snapped = snap(minutes: minutes, step: minuteStep)
        return clampStart(start: snapped, duration: duration)
    }

    private func minutesFromOffset(_ y: CGFloat) -> Int {
        let minutes = Int((y / (hourHeight * zoomScale)) * 60)
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

    private func nextItem(afterSeconds seconds: Int) -> TimelineItem? {
        let startMinutes = Int(ceil(Double(seconds) / 60.0))
        let candidates: [(TimelineItem, Int)] = itemsForSelectedDate.compactMap { item in
            guard let minutes = item.startMinutes else { return nil }
            return (item, minutes)
        }
        return candidates
            .filter { $0.1 >= startMinutes }
            .min(by: { $0.1 < $1.1 })?
            .0
    }

    private func isOverlapping(start: Int, duration: Int, excluding id: UUID?, on date: Date) -> Bool {
        let end = start + duration
        return items.contains { item in
            if let id, item.id == id { return false }
            guard let itemStart = item.startMinutes,
                  let dropDate = item.dropDate,
                  Calendar.current.isDate(dropDate, inSameDayAs: date)
            else { return false }
            let itemEnd = itemStart + item.durationMinutes
            return start < itemEnd && end > itemStart
        }
    }

    static func timeRangeText(startMinutes: Int?, durationMinutes: Int) -> String {
        guard let startMinutes else { return "" }
        let start = minutesToTime(startMinutes)
        let end = minutesToTime(startMinutes + durationMinutes)
        return "\(start) - \(end)"
    }

    private static func minutesToTime(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        return String(format: "%02d:%02d", h, m)
    }

    private func persistItems() {
        repository.saveItems(items)
    }

    private func selectedDropDate(for date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
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
}


extension TimelineViewModel {
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
