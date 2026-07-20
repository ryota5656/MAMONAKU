import Foundation
import SwiftUI
import Combine
import ActivityKit
import UserNotifications

@MainActor
final class TimelineViewModel: ObservableObject, TimelineDelegate {
    private let repository: TimelineRepositoryProtocol

    @Published var state = TimelineViewState()
    
    private let tutorialCompletedKey = "tutorial.firstRun.completed"
    private let isRadialMenuEnabled = true
    private var isRunningInPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
    
    let hourHeight: CGFloat = 80
    let timeColumnWidth: CGFloat = 52
    let timelinePadding: CGFloat = 20
    let minuteStep: Int = 5

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
    @Published var editingItemID: UUID?

    // 長押しで空きに置く「仮」アイテム（日付・開始分）。タイトル入力後に確定 or 取り消し
    @Published var pendingPlacement: (date: Date, startMinutes: Int)?

    // 編集モード解除直後の再入を防ぐ（タップ解除と長押し・ドラッグ開始の競合対策）
    private var lastEditModeExitedAt: Date?
    private let editModeReenterCooldown: TimeInterval = 0.6

    private let minResizeDurationMinutes: Int = 15
    private let resizeDurationStepMinutes: Int = 5
    private var calendarSyncTimer: AnyCancellable?
    private var liveActivityRefreshTask: Task<Void, Never>?
    private var commitSyncObserver: NSObjectProtocol?
    private var foregroundRefreshObserver: NSObjectProtocol?
    private let startNotificationScheduler = TimelineStartNotificationScheduler()
    private let bufferNotificationScheduler = TimelineBufferNotificationScheduler()
    private let liveActivityNamePrefix = "timeline-item:"
    private let liveActivityStackName = "timeline-stack"
    private static let defaultGlobalBufferMinutes = 10
    private static let minBufferMinutes = 1
    private static let maxBufferMinutes = 120

    init(
        repository: TimelineRepositoryProtocol? = nil,
        initialItems: [TimelineItem]? = nil,
        enablePolling: Bool = true
    ) {
        self.repository = repository ?? TimelineRepository()
        if let initialItems {
            items = initialItems
        } else {
            bootstrapItems()
        }
        if enablePolling {
            startCalendarSyncPolling()
        }
        state.isLiveActivitySyncPending = LiveActivitySyncCoordinator.isPending
        commitSyncObserver = NotificationCenter.default.addObserver(
            forName: LiveActivitySyncCoordinator.commitNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.commitPendingLiveActivitySync()
            }
        }
        foregroundRefreshObserver = NotificationCenter.default.addObserver(
            forName: LiveActivitySyncCoordinator.foregroundRefreshNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshLiveActivityIfOverdue()
            }
        }
    }

    deinit {
        if let commitSyncObserver {
            NotificationCenter.default.removeObserver(commitSyncObserver)
        }
        if let foregroundRefreshObserver {
            NotificationCenter.default.removeObserver(foregroundRefreshObserver)
        }
    }

    // MARK: - TimelineDelegate

    func timelineDidAppear(ensureTutorialTask: () -> Void) {
        state.isTaskSheetPresented = true
        state.taskSheetDetent = TaskSheetPresentation.peek
        startFirstRunTutorialIfNeeded(ensureTutorialTask: ensureTutorialTask)
    }

    func timelineItemsDidChange(hasPlacedTutorialTaskAfterNow: () -> Bool) {
        if state.tutorialStep == .placeTaskAfterNow, hasPlacedTutorialTaskAfterNow() {
            state.tutorialStep = .confirmCountdown
        }
    }

    func timelineDropPreviewDidChange(previewExists: Bool) {
        guard state.isDraggingTask, previewExists else { return }
        state.taskSheetDetent = TaskSheetPresentation.peek
    }

    func timelineToggleHeaderExpanded() {
        state.isHeaderExpanded.toggle()
    }

    func timelineOpenTaskSheet() {
        state.isTaskSheetPresented = true
        state.taskSheetSelectedTab = .timeline
        if state.tutorialStep == .openTaskList {
            state.tutorialStep = .placeTaskAfterNow
            state.taskSheetDetent = TaskSheetPresentation.medium
        } else if sheetDetentIsCollapsed {
            state.taskSheetDetent = TaskSheetPresentation.medium
        }
    }

    private var sheetDetentIsCollapsed: Bool {
        state.taskSheetDetent == TaskSheetPresentation.peek
    }

    func timelineOpenSettings() {
        state.taskSheetDetent = TaskSheetPresentation.peek
        state.taskSheetSelectedTab = .settings
    }

    func timelineRefreshLiveActivityManually() async {
        guard !state.isLiveActivityRefreshing else { return }
        let startedAt = Date()
        state.isLiveActivityRefreshing = true
        await commitPendingLiveActivitySync(force: true)
        let remainingDisplayTime = 1.0 - Date().timeIntervalSince(startedAt)
        if remainingDisplayTime > 0 {
            try? await Task.sleep(nanoseconds: UInt64(remainingDisplayTime * 1_000_000_000))
        }
        state.isLiveActivityRefreshing = false
    }

    func timelineAdvanceTutorialStep() {
        guard let step = state.tutorialStep else { return }
        switch step {
        case .openTaskList:
            state.tutorialStep = .placeTaskAfterNow
        case .placeTaskAfterNow:
            state.tutorialStep = .confirmCountdown
        case .confirmCountdown:
            state.tutorialStep = .explainLongPress
        case .explainLongPress:
            state.tutorialStep = .explainLiveActivityFromPlus
        case .explainLiveActivityFromPlus:
            state.tutorialStep = .explainSettingsAndSubscription
        case .explainSettingsAndSubscription:
            state.tutorialStep = nil
            UserDefaults.standard.set(true, forKey: tutorialCompletedKey)
        }
    }

    func timelineRadialAction(at location: CGPoint, in size: CGSize) -> TimelineRadialAction? {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let threshold: CGFloat = 22
        for action in TimelineRadialAction.allCases {
            let target = CGPoint(x: center.x + action.offset.width, y: center.y + action.offset.height)
            let dx = location.x - target.x
            let dy = location.y - target.y
            if sqrt(dx * dx + dy * dy) <= threshold {
                return action
            }
        }
        return nil
    }

    func timelineIsRadialMenuEnabled() -> Bool { isRadialMenuEnabled }

    func timelineTriggerRadialAction(_ action: TimelineRadialAction) {
        switch action {
        case .settings:
            timelineOpenSettings()
        case .refreshLiveActivity:
            Task { await timelineRefreshLiveActivityManually() }
        }
    }

    private func startFirstRunTutorialIfNeeded(ensureTutorialTask: () -> Void) {
        guard !isRunningInPreview else {
            state.tutorialStep = nil
            return
        }
        guard !UserDefaults.standard.bool(forKey: tutorialCompletedKey) else { return }
        ensureTutorialTask()
        state.tutorialStep = .openTaskList
    }
   // ストックのタスクをドロップ位置の時刻にタイムラインへ配置する
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

   // タイムライン上のアイテムを別の位置・日付にドロップで移動する（onDrop 用）
    func moveItemTo(item: TimelineItem, dropY: CGFloat, on date: Date) {
        let start = startMinutesForDrop(duration: item.durationMinutes, dropY: dropY, on: date)
        guard !isOverlapping(start: start, duration: item.durationMinutes, excluding: item.id, on: date) else { return }
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].startMinutes = start
        items[index].dropDate = selectedDropDate(for: date)
        persistItems()
    }

    private let longPressPlaceDurationMinutes: Int = 30
    private let longPressPlaceStepMinutes: Int = 5

   // 空き箇所を長押ししたとき: 30分単位で仮配置を開始（重なりがなければ pending にセット）
    func startPendingPlacement(date: Date, y: CGFloat) {
        let minutes = minutesFromOffset(y, on: date)
        let snapped = snap(minutes: minutes, step: longPressPlaceStepMinutes)
        let start = clampStart(start: snapped, duration: longPressPlaceDurationMinutes)
        guard !isOverlapping(start: start, duration: longPressPlaceDurationMinutes, excluding: nil, on: date) else { return }
        pendingPlacement = (date: Calendar.current.startOfDay(for: date), startMinutes: start)
    }

   // 仮配置を確定（タイトルを付けてアイテム追加）
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

   // 仮配置を取り消し
    func cancelPendingPlacement() {
        pendingPlacement = nil
    }

   // Debug: 指定時刻から指定分のテストタスクをタイムラインに追加
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

   // ストックに新規タスクを追加する（未配置のまま）
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

   // リサイズハンドル操作中の所要時間プレビューを更新する
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

   // リサイズ操作を確定し、タスクの所要時間を保存する
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
    
    // MARK: Drop preview

   // ドラッグ中のドロップ位置に合わせてゴーストプレビューを更新する
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

   // ストック内のタスク並び順を変更する（タイムライン配置済みは末尾に維持）
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

   // タスクを削除する（カレンダーイベントも連動削除）
    func deleteItem(id: UUID) {
        repository.deleteItemAndEvent(id: id)
        items = repository.fetchItems()
        rescheduleTimelineNotifications()
        markLiveActivitySyncPending()
    }

   // タイムライン上のアイテムをストックに戻す（開始時刻・日付を解除）
    func returnItemToStock(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        dropPreview = nil
        previewItemID = nil
        dragItemID = nil
        items[index].startMinutes = nil
        items[index].dropDate = nil
        persistItems()
    }

   // タイムライン上のアイテムを完了にする（isCompleted = true、タイムライン上には残す）
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

   // タイムライン上のアイテムの完了を解除する（isCompleted = false）
    func uncompleteItem(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isCompleted = false
        persistItems()
    }

   // タイムライン上のタスクタイトルをインライン編集で更新する
    func updateItemTitle(id: UUID, title: String) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        guard items[index].title != trimmedTitle else { return }
        let current = items[index]
        items[index] = TimelineItem(
            id: current.id,
            title: trimmedTitle,
            durationMinutes: current.durationMinutes,
            startMinutes: current.startMinutes,
            dropDate: current.dropDate,
            isCompleted: current.isCompleted,
            priority: current.priority,
            isAllDay: current.isAllDay,
            bufferMinutes: current.bufferMinutes
        )
        persistItems()
    }

   // タスク編集シートからタイトル・時間・優先度をまとめて更新する
    func updateItemDetails(
        id: UUID,
        title: String,
        durationMinutes: Int,
        priority: TaskPriority
    ) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        let current = items[index]
        let clampedDuration = clampDuration(start: current.startMinutes ?? 0, duration: durationMinutes)
        if let startMinutes = current.startMinutes, let dropDate = current.dropDate {
            guard !isOverlapping(start: startMinutes, duration: clampedDuration, excluding: id, on: dropDate) else { return }
        }
        items[index] = TimelineItem(
            id: current.id,
            title: trimmedTitle,
            durationMinutes: clampedDuration,
            startMinutes: current.startMinutes,
            dropDate: current.dropDate,
            isCompleted: current.isCompleted,
            priority: priority,
            isAllDay: current.isAllDay,
            bufferMinutes: current.bufferMinutes
        )
        persistItems()
    }

   // 編集モードを解除（アイテム以外タップ時など）。解除直後の再入ガードをセットする。
    func exitEditMode() {
        editMode = .inactive
        editingItemID = nil
        dragItemID = nil
        dropPreview = nil
        lastEditModeExitedAt = Date()
    }

   // 編集モードへ入るリクエスト。解除直後のクールダウン中は無視して false を返す。
    func requestEnterEditMode(for itemID: UUID? = nil) -> Bool {
        if isInEditModeExitCooldown() {
            lastEditModeExitedAt = nil
            return false
        }
        lastEditModeExitedAt = nil
        editingItemID = itemID
        editMode = .active
        return true
    }

   // 解除直後のクールダウン中か（ドラッグ開始時もこの判定を使う）
    func isInEditModeExitCooldown() -> Bool {
        guard let t = lastEditModeExitedAt else { return false }
        return Date().timeIntervalSince(t) < editModeReenterCooldown
    }

    // MARK: 表示用クエリ

   // 選択中日付のタイムライン表示用アイテム（終日を除く）
    var itemsForSelectedDate: [TimelineItem] {
        items(for: selectedDate)
    }

   // 指定日のタイムライン表示用アイテム（終日を除く）
    func items(for date: Date) -> [TimelineItem] {
        items.filter { item in
            guard !item.isAllDay else { return false }
            guard let dropDate = item.dropDate else { return false }
            return Calendar.current.isDate(dropDate, inSameDayAs: date)
        }
    }

   // 指定日の終日タスク一覧
    func allDayItems(for date: Date) -> [TimelineItem] {
        items.filter { item in
            guard item.isAllDay else { return false }
            guard let dropDate = item.dropDate else { return false }
            return Calendar.current.isDate(dropDate, inSameDayAs: date)
        }
    }

   // 日付から0時起算の経過分を返す（現在時刻ライン描画用）
    func minutesSinceMidnight(date: Date) -> Int {
        let cal = Calendar.current
        let comps = cal.dateComponents([.hour, .minute], from: date)
        let h = comps.hour ?? 0
        let m = comps.minute ?? 0
        return (h * 60) + m
    }

   // 日付を HH:mm 形式の文字列に変換する
    func currentTimeText(date: Date) -> String {
        let cal = Calendar.current
        let comps = cal.dateComponents([.hour, .minute], from: date)
        let h = comps.hour ?? 0
        let m = comps.minute ?? 0
        return String(format: "%02d:%02d", h, m)
    }

   // 開始分をタイムライン上の Y オフセット（pt）に変換する
    func yOffset(for startMinutes: Int) -> CGFloat {
        (CGFloat(startMinutes) / 60) * hourHeight * zoomScale
    }

   // 所要時間（分）をタイムライン上の高さ（pt）に変換する
    func heightForDuration(_ minutes: Int) -> CGFloat {
        (CGFloat(minutes) / 60) * hourHeight * zoomScale
    }

    private var appGroupDefaults: UserDefaults? {
        UserDefaults(suiteName: AppGroup.id)
    }

    private var isBufferNotificationEnabled: Bool {
        let isSubscribed = appGroupDefaults?.bool(forKey: SubscriptionManager.subscriptionStateUserDefaultsKey) ?? false
        let isEnabledByUser = appGroupDefaults?.object(forKey: AppGroup.bufferNotificationEnabledKey) as? Bool ?? false
        return isSubscribed && isEnabledByUser
    }

    private var isLiveActivityEnabled: Bool {
        let isEnabledByUser = appGroupDefaults?.object(forKey: AppGroup.liveActivityEnabledKey) as? Bool ?? true
        return isEnabledByUser
    }

    private var isPlusSubscriber: Bool {
        appGroupDefaults?.bool(forKey: SubscriptionManager.subscriptionStateUserDefaultsKey) ?? false
    }

    private var liveActivityPlanScope: LiveActivityScheduleBuilder.PlanScope {
        isPlusSubscriber ? .plus : .free
    }

    private func effectiveBufferMinutes(for item: TimelineItem) -> Int? {
        guard isBufferNotificationEnabled else { return nil }
        let global = appGroupDefaults?.object(forKey: AppGroup.globalBufferMinutesKey) as? Int
            ?? Self.defaultGlobalBufferMinutes
        let candidate = item.bufferMinutes ?? global
        let clamped = min(max(candidate, Self.minBufferMinutes), Self.maxBufferMinutes)
        return clamped
    }

   // 短いフォーマットの残り時間（例: 14:32 / 1:23）
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
        let snapped = snap(minutes: rawDuration, step: resizeDurationStepMinutes)
        let startMinutes = item.startMinutes ?? 0
        return clampDuration(start: startMinutes, duration: snapped)
    }

    private func startMinutesForDrop(duration: Int, dropY: CGFloat, on date: Date) -> Int {
        let minutes = minutesFromOffset(dropY, on: date)
        let snapped = snap(minutes: minutes, step: minuteStep)
        return clampStart(start: snapped, duration: duration)
    }

   // 指定日の列でY座標→開始分
    private func minutesFromOffset(_ y: CGFloat, on date: Date) -> Int {
        minutesFromOffset(y)
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

   // 指定秒数（0時からの経過秒）より後に開始する最初の予定を返す。カウントダウン0まで「次」を維持し、Dynamic Island / Live Activity で次の予定に切り替えるため秒単位で比較する。
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

   // 今日の予定から、指定秒数より後に開始する最初の予定を返す。
    private func nextTodayItem(afterSeconds seconds: Int) -> TimelineItem? {
        let cal = Calendar.current
        let candidates: [(TimelineItem, Int)] = items.compactMap { item in
            guard let minutes = item.startMinutes, let dropDate = item.dropDate else { return nil }
            guard cal.isDateInToday(dropDate) else { return nil }
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

   // 開始・終了時刻の表示用文字列（例: 09:00 - 10:30）を生成する
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
        rescheduleTimelineNotifications()
        markLiveActivitySyncPending()
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
        rescheduleTimelineNotifications()
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
        rescheduleTimelineNotifications()
        markLiveActivitySyncPending()
    }

    private func rescheduleTimelineNotifications() {
        startNotificationScheduler.reschedule(items: items)
        bufferNotificationScheduler.reschedule(items: items)
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
        let maxDuration = max(minResizeDurationMinutes, (24 * 60) - start)
        return max(minResizeDurationMinutes, min(maxDuration, duration))
    }

    private func markLiveActivitySyncPending() {
        guard isLiveActivityEnabled else { return }
        LiveActivitySyncCoordinator.markPending()
        state.isLiveActivitySyncPending = true
        print("[LiveActivity] Sync pending — commit on background or manual refresh")
    }

    /// 未反映の変更があれば Live Activity と Cloud Tasks を更新する。
    func commitPendingLiveActivitySync(force: Bool = false) async {
        guard force || LiveActivitySyncCoordinator.isPending else { return }
        guard isLiveActivityEnabled else {
            LiveActivitySyncCoordinator.clearPending()
            state.isLiveActivitySyncPending = false
            return
        }
        print("[LiveActivity] Committing pending sync (force=\(force))")
        await startOrUpdateLiveActivity()
        LiveActivitySyncCoordinator.clearPending()
        state.isLiveActivitySyncPending = false
    }
}

// MARK: - LiveActivity
extension TimelineViewModel {

    /// 今日の予定からスタック型 Live Activity（最大3件）を作成・更新し、Cloud Tasks にローテーションを予約する。
    func startOrUpdateLiveActivity() async {
        guard isLiveActivityEnabled else {
            await endLiveActivityIfNeeded()
            await LiveActivityPushService.shared.syncSchedule(rotations: [])
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let now = Date()
        let planScope = liveActivityPlanScope
        let entries = LiveActivityScheduleBuilder.entriesForToday(
            items: items,
            referenceDate: now,
            planScope: planScope
        )
        let (startIndex, window) = LiveActivityScheduleBuilder.currentWindow(
            entries: entries,
            now: now,
            planScope: planScope
        )

        guard !window.isEmpty else {
            await endLiveActivityIfNeeded()
            await LiveActivityPushService.shared.syncSchedule(rotations: [])
            return
        }

        let schedule = LiveActivityScheduleBuilder.buildTaskItems(
            from: window,
            now: now,
            bufferMinutes: { [weak self] item in
                self?.effectiveBufferMinutes(for: item)
            }
        )
        let rotations = LiveActivityScheduleBuilder.buildRotations(
            entries: entries,
            startIndex: startIndex,
            now: now,
            planScope: planScope,
            bufferMinutes: { [weak self] item in
                self?.effectiveBufferMinutes(for: item)
            }
        )

        print("[LiveActivity] Plan scope: \(planScope == .plus ? "PLUS" : "free"), entries: \(entries.count), visible: \(schedule.count)")

        let staleDate = entries[startIndex].startDate
        await upsertStackLiveActivity(schedule: schedule, staleDate: staleDate)
        scheduleNextLocalRotation(rotations)
        await LiveActivityPushService.shared.syncSchedule(rotations: rotations)
    }

    /// プライマリのカウントダウンが 0:00 を過ぎていたら、次の予定へ切り替える。
    func refreshLiveActivityIfOverdue() async {
        guard isLiveActivityEnabled else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        guard let activity = Activity<MAMONAKULiveActivityAttributes>.activities.first(where: {
            isManagedLiveActivity($0)
        }) else { return }

        guard let primary = activity.content.state.schedule.first,
              let target = primary.nextStartDate,
              target <= Date()
        else { return }

        print("[LiveActivity] Overdue refresh — primary target was \(target.formatted())")
        await startOrUpdateLiveActivity()
    }

    /// Cloud Tasks が届かない場合のフォールバック。次のローテーション時刻にローカル更新する。
    private func scheduleNextLocalRotation(_ rotations: [LiveActivityScheduleBuilder.Rotation]) {
        liveActivityRefreshTask?.cancel()

        guard let next = rotations
            .filter({ $0.switchAt > Date() })
            .min(by: { $0.switchAt < $1.switchAt })
        else { return }

        liveActivityRefreshTask = Task { [weak self] in
            let delay = next.switchAt.timeIntervalSinceNow
            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
            guard !Task.isCancelled else { return }
            await self?.handleLocalRotation(next)
        }

        print("[LiveActivity] Local rotation scheduled at \(next.switchAt.formatted()) (\(next.reason))")
    }

    private func handleLocalRotation(_ rotation: LiveActivityScheduleBuilder.Rotation) async {
        print("[LiveActivity] Local rotation fired — \(rotation.reason)")
        if rotation.shouldEndActivity {
            await endLiveActivityIfNeeded()
            liveActivityRefreshTask?.cancel()
            liveActivityRefreshTask = nil
            return
        }
        await startOrUpdateLiveActivity()
    }

    private func endLiveActivityIfNeeded() async {
        liveActivityRefreshTask?.cancel()
        liveActivityRefreshTask = nil

        let activities = Activity<MAMONAKULiveActivityAttributes>.activities
        for liveActivity in activities where isManagedLiveActivity(liveActivity) {
            await liveActivity.end(dismissalPolicy: .immediate)
        }
    }

    private func isManagedLiveActivity(_ activity: Activity<MAMONAKULiveActivityAttributes>) -> Bool {
        activity.attributes.name == liveActivityStackName
            || activity.attributes.name.hasPrefix(liveActivityNamePrefix)
    }

    private func clearLegacyTimelineActivities() async {
        let existingActivities = Activity<MAMONAKULiveActivityAttributes>.activities
        for liveActivity in existingActivities where liveActivity.attributes.name.hasPrefix(liveActivityNamePrefix) {
            await liveActivity.end(dismissalPolicy: .immediate)
        }
    }

    private func upsertStackLiveActivity(schedule: [ActivityTaskItem], staleDate: Date?) async {
        let attributes = MAMONAKULiveActivityAttributes(name: liveActivityStackName)
        let state = MAMONAKULiveActivityAttributes.ContentState(schedule: schedule)
        let content = ActivityContent(state: state, staleDate: staleDate, relevanceScore: 1.0)

        if let existing = Activity<MAMONAKULiveActivityAttributes>.activities.first(where: {
            $0.attributes.name == liveActivityStackName
        }) {
            await existing.update(content)
            print("[LiveActivity] Local update — schedule: \(schedule.map(\.nextTitle).joined(separator: " → "))")
            LiveActivityPushService.shared.observeUpdateToken(for: existing)
            return
        }

        await clearLegacyTimelineActivities()

        do {
            let created = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: .token
            )
            print("[LiveActivity] Created — schedule: \(schedule.map(\.nextTitle).joined(separator: " → "))")
            LiveActivityPushService.shared.observeUpdateToken(for: created)
        } catch {
            print("[LiveActivity] Creation failed: \(error.localizedDescription)")
        }
    }
}

