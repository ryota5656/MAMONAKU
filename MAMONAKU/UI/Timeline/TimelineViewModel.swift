import Foundation
import SwiftUI
import Combine
import ActivityKit
import UserNotifications

@MainActor
class TimelineViewModel: ObservableObject {
    private let repository: TimelineRepositoryProtocol

    @Published var screen = TimelineScreenViewState()
    
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
    private let startNotificationScheduler = TimelineStartNotificationScheduler()
    private let bufferNotificationScheduler = TimelineBufferNotificationScheduler()
    private let liveActivityNamePrefix = "timeline-item:"
    private let maxMultipleLiveActivityCount = 5
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
    }

    // MARK: - Screen events

    // 画面表示時に初回チュートリアルを開始する（未完了かつプレビュー以外）
    func screenOnAppear(ensureTutorialTask: () -> Void) {
        startFirstRunTutorialIfNeeded(ensureTutorialTask: ensureTutorialTask)
    }

    // アイテム変更時にチュートリアル進行を判定する（タスク配置ステップの完了検知）
    func screenOnItemsChanged(hasPlacedTutorialTaskAfterNow: () -> Bool) {
        if screen.tutorialStep == .placeTaskAfterNow, hasPlacedTutorialTaskAfterNow() {
            screen.tutorialStep = .confirmCountdown
        }
    }

    // ドラッグ中にタイムライン上へプレビューが表示されたらタスクシートを閉じる
    func screenOnDropPreviewChanged(previewExists: Bool) {
        guard screen.isTaskSheetPresented, screen.isDraggingTask, previewExists else { return }
        screen.isTaskSheetPresented = false
    }

    // ヘッダー（カウントダウン）の展開・折りたたみを切り替える
    func screenToggleHeaderExpanded() {
        screen.isHeaderExpanded.toggle()
    }

    // タスクリストシートを開く（チュートリアル中は次ステップへ進める）
    func screenOpenTaskSheet() {
        screen.isTaskSheetPresented = true
        if screen.tutorialStep == .openTaskList {
            screen.tutorialStep = .placeTaskAfterNow
        }
    }

    // 設定画面を開く
    func screenOpenSettings() {
        screen.isSettingsPresented = true
    }

    // ラジアルメニューから Live Activity を手動更新する（最低1秒ローディング表示）
    func screenRefreshLiveActivityManually() async {
        guard !screen.isLiveActivityRefreshing else { return }
        let startedAt = Date()
        screen.isLiveActivityRefreshing = true
        await startOrUpdateLiveActivity()
        let remainingDisplayTime = 1.0 - Date().timeIntervalSince(startedAt)
        if remainingDisplayTime > 0 {
            try? await Task.sleep(nanoseconds: UInt64(remainingDisplayTime * 1_000_000_000))
        }
        screen.isLiveActivityRefreshing = false
    }

   // チュートリアルの「次へ」で次のステップへ進む（最終ステップで完了フラグを保存）
    func screenAdvanceTutorialStep() {
        guard let step = screen.tutorialStep else { return }
        switch step {
        case .openTaskList:
            screen.tutorialStep = .placeTaskAfterNow
        case .placeTaskAfterNow:
            screen.tutorialStep = .confirmCountdown
        case .confirmCountdown:
            screen.tutorialStep = .explainLongPress
        case .explainLongPress:
            screen.tutorialStep = .explainLiveActivityFromPlus
        case .explainLiveActivityFromPlus:
            screen.tutorialStep = .explainSettingsAndSubscription
        case .explainSettingsAndSubscription:
            screen.tutorialStep = nil
            UserDefaults.standard.set(true, forKey: tutorialCompletedKey)
        }
    }

   // ＋ボタン長押し中の指位置から、選択中のラジアルメニュー項目を返す
    func screenRadialAction(at location: CGPoint, in size: CGSize) -> TimelineRadialAction? {
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

   // ラジアルメニュー（長押し＋）が有効かどうか
    func screenIsRadialMenuEnabled() -> Bool { isRadialMenuEnabled }

    private func startFirstRunTutorialIfNeeded(ensureTutorialTask: () -> Void) {
        guard !isRunningInPreview else {
            screen.tutorialStep = nil
            return
        }
        guard !UserDefaults.standard.bool(forKey: tutorialCompletedKey) else { return }
        ensureTutorialTask()
        screen.tutorialStep = .openTaskList
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

    private var isMultipleLiveActivityEnabled: Bool {
        let isSubscribed = appGroupDefaults?.bool(forKey: SubscriptionManager.subscriptionStateUserDefaultsKey) ?? false
        let isEnabledByUser = appGroupDefaults?.object(forKey: AppGroup.liveActivityMultipleEnabledKey) as? Bool ?? false
        return isSubscribed && isEnabledByUser
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
}

// MARK: - LiveActivity
extension TimelineViewModel {

   // 今日のこれから始まる予定に Live Activity を作成・更新する
    func startOrUpdateLiveActivity() async {
        print("startOrUpdateLiveActivity")
        guard isLiveActivityEnabled else {
            await endLiveActivityIfNeeded()
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let now = Date()
        let startOfToday = Calendar.current.startOfDay(for: now)
        let candidates = liveActivityCandidates(after: now)
        let maxActivityCount = isMultipleLiveActivityEnabled ? maxMultipleLiveActivityCount : 1
        let remainingItems = Array(candidates.prefix(maxActivityCount))
        await clearExistingTimelineActivities()

        for (index, item) in remainingItems.enumerated() {
            await requestLiveActivity(for: item, at: index, startOfToday: startOfToday)
        }
    }

    private func endLiveActivityIfNeeded() async {
        liveActivityRefreshTask?.cancel()
        liveActivityRefreshTask = nil

        let activities = Activity<MAMONAKULiveActivityAttributes>.activities
        for liveActivity in activities where liveActivity.attributes.name.hasPrefix(liveActivityNamePrefix) {
            await liveActivity.end(dismissalPolicy: .immediate)
        }
    }

    private func liveActivityName(for id: UUID) -> String {
        "\(liveActivityNamePrefix)\(id.uuidString)"
    }

    // 今日の日付で現在時刻より後の最短の予定順に並び替えて返却
    private func liveActivityCandidates(after now: Date) -> [TimelineItem] {
        let calendar = Calendar.current
        let nowSeconds = secondsSinceMidnight(date: now)
        let todayScheduledItems: [TimelineItem] = items
            .filter { item in
                guard let dropDate = item.dropDate, let startMinutes = item.startMinutes else { return false }
                return calendar.isDateInToday(dropDate)
            }
            .sorted { ($0.startMinutes ?? 0) < ($1.startMinutes ?? 0) }
        return todayScheduledItems.filter { ($0.startMinutes ?? 0) * 60 > nowSeconds }
    }

    private func clearExistingTimelineActivities() async {
        let existingActivities = Activity<MAMONAKULiveActivityAttributes>.activities
        for liveActivity in existingActivities where liveActivity.attributes.name.hasPrefix(liveActivityNamePrefix) {
            await liveActivity.end(dismissalPolicy: .immediate)
        }
    }

    // LiveActivityへリクエスト
    private func requestLiveActivity(
        for item: TimelineItem,
        at index: Int,
        startOfToday: Date
    ) async {
        let name = liveActivityName(for: item.id)
        let attributes = MAMONAKULiveActivityAttributes(name: name)
        let startDate = liveActivityStartDate(for: item, startOfToday: startOfToday)
        let bufferMinutes = effectiveBufferMinutes(for: item)
        let task = ActivityTaskItem(
            nextTitle: item.title,
            nextStartDate: startDate,
            countdownStartDate: Date(),
            remainingTimeShort: startDate.map { Self.shortCountdownString(to: $0) } ?? "--:--",
            bufferMinutes: bufferMinutes
        )
        let state = MAMONAKULiveActivityAttributes.ContentState(schedule: [task])
        let relevanceScore = max(0.01, 1.0 - (Double(index) * 0.05))
        let content = ActivityContent(state: state, staleDate: nil, relevanceScore: relevanceScore)
        let dismissAfter10Seconds = (startDate ?? Date()).addingTimeInterval(10)

        print("startOrUpdateLiveActivityCreate")
        do {
            let created = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            await created.end(dismissalPolicy: .after(dismissAfter10Seconds))
        } catch {
            print("Live Activity creation failed: \(error.localizedDescription)")
        }
    }

    private func liveActivityStartDate(for item: TimelineItem, startOfToday: Date) -> Date? {
        guard let startMinutes = item.startMinutes else { return nil }
        return Calendar.current.date(byAdding: .minute, value: startMinutes, to: startOfToday)
    }
}

