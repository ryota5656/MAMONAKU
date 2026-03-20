import Foundation
import SwiftUI
import Combine
import ActivityKit

@MainActor
class TimelineViewModel: ObservableObject {
    private let repository: TimelineRepositoryProtocol
    
    let hourHeight: CGFloat = 80
    let timeColumnWidth: CGFloat = 52
    let timelinePadding: CGFloat = 20
    let minuteStep: Int = 15

    @Published var items: [TimelineItem] = []
    @Published var dropPreview: TimelineItem?
    @Published var previewItemID: UUID?
    @Published var dragItemID: UUID?
    @Published var resizePreview: TimelineItem?
    @Published var resizingItemID: UUID?
    @Published var chipsExpanded = false
    @Published var editMode: EditMode = .inactive
    @Published var selectedDate = Date()
    @Published var isTwoDayView = false
    @Published var zoomScale: CGFloat = 1.0

    /// 長押しで空きに置く「仮」アイテム（日付・開始分）。タイトル入力後に確定 or 取り消し
    @Published var pendingPlacement: (date: Date, startMinutes: Int)?

    /// 編集モード解除直後の再入を防ぐ（タップ解除と長押し・ドラッグ開始の競合対策）
    private var lastEditModeExitedAt: Date?
    private let editModeReenterCooldown: TimeInterval = 0.6

    private let minDurationStep: Int = 15
    private var activity: Activity<MAMONAKULiveActivityAttributes>?
    private var calendarSyncTimer: AnyCancellable?
    private var liveActivityRefreshTask: Task<Void, Never>?

    init(
        repository: TimelineRepositoryProtocol = TimelineRepository(),
        initialItems: [TimelineItem]? = nil,
        enablePolling: Bool = true
    ) {
        self.repository = repository
        if let initialItems {
            items = initialItems
        } else {
            bootstrapItems()
        }
        if enablePolling {
            startCalendarSyncPolling()
        }
    }
    
    func addItem(item: TimelineItem, dropY: CGFloat, on date: Date) {
        let start = startMinutesForDrop(duration: item.durationMinutes, dropY: dropY, on: date)
        guard !isOverlapping(start: start, duration: item.durationMinutes, excluding: item.id, on: date) else { return }
        let updated = TimelineItem(
            id: item.id,
            title: item.title,
            durationMinutes: item.durationMinutes,
            startMinutes: start,
            dropDate: selectedDropDate(for: date),
            priority: item.priority
        )
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = updated
        } else {
            items.append(updated)
        }
        persistItems()
    }

    /// タイムライン上のアイテムを別の位置・日付にドロップで移動する（onDrop 用）
    func moveItemTo(item: TimelineItem, dropY: CGFloat, on date: Date) {
        let start = startMinutesForDrop(duration: item.durationMinutes, dropY: dropY, on: date)
        guard !isOverlapping(start: start, duration: item.durationMinutes, excluding: item.id, on: date) else { return }
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].startMinutes = start
        items[index].dropDate = selectedDropDate(for: date)
        persistItems()
    }

    private let longPressPlaceDurationMinutes: Int = 30
    private let longPressPlaceStepMinutes: Int = 30

    /// 空き箇所を長押ししたとき: 30分単位で仮配置を開始（重なりがなければ pending にセット）
    func startPendingPlacement(date: Date, y: CGFloat) {
        let minutes = minutesFromOffset(y, on: date)
        let snapped = snap(minutes: minutes, step: longPressPlaceStepMinutes)
        let start = clampStart(start: snapped, duration: longPressPlaceDurationMinutes)
        guard !isOverlapping(start: start, duration: longPressPlaceDurationMinutes, excluding: nil, on: date) else { return }
        pendingPlacement = (date: Calendar.current.startOfDay(for: date), startMinutes: start)
    }

    /// 仮配置を確定（タイトルを付けてアイテム追加）
    func commitPendingPlacement(title: String) {
        guard let pending = pendingPlacement else { return }
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else {
            cancelPendingPlacement()
            return
        }
        let newItem = TimelineItem(
            title: t,
            durationMinutes: longPressPlaceDurationMinutes,
            startMinutes: pending.startMinutes,
            dropDate: pending.date
        )
        items.append(newItem)
        persistItems()
        pendingPlacement = nil
    }

    /// 仮配置を取り消し
    func cancelPendingPlacement() {
        pendingPlacement = nil
    }

    /// Debug: 指定時刻から指定分のテストタスクをタイムラインに追加
    func addTestTask(startDate: Date, durationMinutes: Int) {
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: startDate)
        let startMinutes = Int(startDate.timeIntervalSince(startOfDay) / 60)
        let item = TimelineItem(
            title: "テスト",
            durationMinutes: durationMinutes,
            startMinutes: startMinutes,
            dropDate: startOfDay,
            priority: .medium
        )
        items.append(item)
        persistItems()
    }

    func addStockItem(title: String, durationMinutes: Int, priority: TaskPriority = .medium) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        items.append(
            TimelineItem(
                title: trimmedTitle,
                durationMinutes: durationMinutes,
                priority: priority
            )
        )
        persistItems()
    }

    // MARK: Resize - アイテムの時間変更
    func updateResizePreview(item: TimelineItem, deltaY: CGFloat) {
        print("updateResizePreview")
        guard let startMinutes = item.startMinutes else { return }
        let duration = durationForResize(item: item, deltaY: deltaY)
        let baseDate = item.dropDate ?? selectedDate
        resizePreview = TimelineItem(
            title: item.title,
            durationMinutes: duration,
            startMinutes: startMinutes,
            dropDate: selectedDropDate(for: baseDate),
            priority: item.priority
        )
        resizingItemID = item.id
    }

    func commitResize(item: TimelineItem, deltaY: CGFloat) {
        print("commitResize")
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
    
    // MARK: Resize - アイテムをストックから置く時
    func updatePreview(item: TimelineItem, dropY: CGFloat, on date: Date) {
        print("updatePreview")
        let start = startMinutesForDrop(duration: item.durationMinutes, dropY: dropY, on: date)
        dropPreview = TimelineItem(
            id: item.id,
            title: item.title,
            durationMinutes: item.durationMinutes,
            startMinutes: start,
            dropDate: selectedDropDate(for: date),
            priority: item.priority
        )
    }

    // MARK: ストック内のアイテム移動
    func moveTaskItems(from: IndexSet, to: Int) {
        print("moveTaskItems")
        var tasks = items.filter { $0.dropDate == nil }
        let scheduled = items.filter { $0.dropDate != nil }
        let clampedTo = min(to, tasks.count)
        tasks.move(fromOffsets: from, toOffset: clampedTo)
        items = tasks + scheduled
        persistItems()
    }
    
    // MARK: 削除
    func deleteItem(id: UUID) {
        repository.deleteItemAndEvent(id: id)
        items = repository.fetchItems()
    }

    /// タイムライン上のアイテムをストックに戻す（開始時刻・日付を解除）
    func returnItemToStock(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        dropPreview = nil
        previewItemID = nil
        dragItemID = nil
        items[index].startMinutes = nil
        items[index].dropDate = nil
        persistItems()
    }

    /// タイムライン上のアイテムを完了にする（isCompleted = true、タイムライン上には残す）
    func completeItem(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        dropPreview = nil
        previewItemID = nil
        dragItemID = nil
        resizePreview = nil
        resizingItemID = nil
        items[index].isCompleted = true
        persistItems()
    }

    /// タイムライン上のアイテムの完了を解除する（isCompleted = false）
    func uncompleteItem(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isCompleted = false
        persistItems()
    }

    /// 編集モードを解除（アイテム以外タップ時など）。解除直後の再入ガードをセットする。
    func exitEditMode() {
        editMode = .inactive
        dragItemID = nil
        dropPreview = nil
        lastEditModeExitedAt = Date()
    }

    /// 編集モードへ入るリクエスト。解除直後のクールダウン中は無視して false を返す。
    func requestEnterEditMode() -> Bool {
        if isInEditModeExitCooldown() {
            lastEditModeExitedAt = nil
            return false
        }
        lastEditModeExitedAt = nil
        editMode = .active
        return true
    }

    /// 解除直後のクールダウン中か（ドラッグ開始時もこの判定を使う）
    func isInEditModeExitCooldown() -> Bool {
        guard let t = lastEditModeExitedAt else { return false }
        return Date().timeIntervalSince(t) < editModeReenterCooldown
    }

    // MARK: その他
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

    /// Live Activity / Dynamic Island を更新。秒ごとの残り時間表示は拡張側の
    /// `Text(timerInterval:)` に任せ、アプリ側は「次の予定」が変わる時だけ更新する。
    func updateLiveActivity() {
        liveActivityRefreshTask?.cancel()
        liveActivityRefreshTask = nil
        let nowSeconds = secondsSinceMidnight(date: Date())
        if let next = nextItem(afterSeconds: nowSeconds) {
            let cal = Calendar.current
            let startDate = cal.date(
                bySettingHour: (next.startMinutes ?? 0) / 60,
                minute: (next.startMinutes ?? 0) % 60,
                second: 0,
                of: Date()
            ) ?? Date()
            Task {
                await startOrUpdate(nextTitle: next.title, nextStartDate: startDate)
            }
            let interval = startDate.timeIntervalSinceNow
            if interval > 0 {
                liveActivityRefreshTask = Task { [weak self] in
                    try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        self?.updateLiveActivity()
                    }
                }
            }
        } else {
            Task {
                await startOrUpdate(nextTitle: "No Plan", nextStartDate: nil)
            }
        }
    }

    /// 短いフォーマットの残り時間（例: 14:32 / 1:23）
    private static func shortCountdownString(to targetDate: Date) -> String {
        let s = max(0, Int(targetDate.timeIntervalSinceNow))
        if s >= 3600 {
            let h = s / 3600
            let m = (s % 3600) / 60
            return String(format: "%d:%02d", h, m)
        }
        let m = s / 60
        let sec = s % 60
        return String(format: "%d:%02d", m, sec)
    }

    private func durationForResize(item: TimelineItem, deltaY: CGFloat) -> Int {
        let deltaMinutes = Int((deltaY / (hourHeight * zoomScale)) * 60)
        let rawDuration = item.durationMinutes + deltaMinutes
        let snapped = snap(minutes: rawDuration, step: minDurationStep)
        let startMinutes = item.startMinutes ?? 0
        return clampDuration(start: startMinutes, duration: snapped)
    }

    private func startMinutesForDrop(duration: Int, dropY: CGFloat, on date: Date) -> Int {
        let minutes = minutesFromOffset(dropY, on: date)
        let snapped = snap(minutes: minutes, step: minuteStep)
        return clampStart(start: snapped, duration: duration)
    }

    private func minutesFromOffset(_ y: CGFloat) -> Int {
        let minutes = Int((y / (hourHeight * zoomScale)) * 60)
        return max(0, min(24 * 60, minutes))
    }

    /// 指定日の列でY座標→開始分
    private func minutesFromOffset(_ y: CGFloat, on date: Date) -> Int {
        minutesFromOffset(y)
    }

    private func secondsSinceMidnight(date: Date) -> Int {
        let cal = Calendar.current
        let comps = cal.dateComponents([.hour, .minute, .second], from: date)
        let h = comps.hour ?? 0
        let m = comps.minute ?? 0
        let s = comps.second ?? 0
        return (h * 3600) + (m * 60) + s
    }

    /// 指定秒数（0時からの経過秒）より後に開始する最初の予定を返す。カウントダウン0まで「次」を維持し、Dynamic Island / Live Activity で次の予定に切り替えるため秒単位で比較する。
    private func nextItem(afterSeconds seconds: Int) -> TimelineItem? {
        let candidates: [(TimelineItem, Int)] = itemsForSelectedDate.compactMap { item in
            guard let minutes = item.startMinutes else { return nil }
            return (item, minutes * 60)
        }
        return candidates
            .filter { $0.1 > seconds }
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
    
    private func bootstrapItems() {
        let stored = repository.fetchItems()
        if stored.isEmpty {
            repository.saveItems(items)
        } else {
            items = stored
        }
    }

    private func startCalendarSyncPolling() {
        calendarSyncTimer = Timer
            .publish(every: 10, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refreshItemsFromRepository()
            }
    }

    private func refreshItemsFromRepository() {
        let stored = repository.fetchItems()
        guard stored != items else { return }
        items = stored
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
        print("startOrUpdate")
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = MAMONAKULiveActivityAttributes(name: "testRoom08")
        let countdownStartDate = nextStartDate.map { _ in Date() }
        let remainingShort = nextStartDate.map { Self.shortCountdownString(to: $0) } ?? "--:--"
        let state = MAMONAKULiveActivityAttributes.ContentState(
            nextTitle: nextTitle,
            nextStartDate: nextStartDate,
            countdownStartDate: countdownStartDate,
            remainingTimeShort: remainingShort
        )

        if activity == nil {
            activity = Activity<MAMONAKULiveActivityAttributes>.activities.first(where: { $0.attributes.name == attributes.name })
        }

        if let activity {
            await activity.update(using: state)
            return
        }

        activity = try? Activity.request(
            attributes: attributes,
            contentState: state,
            pushType: nil
        )
    }
}

