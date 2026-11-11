import Foundation
import Observation

/// タイムライン画面のロジック。
///
/// 予定の編集ルールは `TimelineItemEditUseCase`、保存は `TimelineRepository`、
/// 通知と Live Activity はそれぞれのリポジトリに任せ、ここでは画面の状態遷移だけを扱う。
@Observable
@MainActor
final class TimelineViewModel: TimelineDelegate {
    // MARK: - State

    private(set) var state: TimelineViewState

    // MARK: - Dependencies

    @ObservationIgnored private let repository: TimelineRepository
    @ObservationIgnored private let notificationRepository: TimelineNotificationRepository
    @ObservationIgnored private let liveActivityRepository: LiveActivityRepository
    /// 初回チュートリアルの完了フラグを置く UserDefaults
    @ObservationIgnored private let localDefaults: UserDefaults
    @ObservationIgnored private let editUseCase: TimelineItemEditUseCase
    @ObservationIgnored private let now: () -> Date
    /// 「更新中」表示を最低限出し続ける時間（一瞬で消えると反映されたか分からないため）
    @ObservationIgnored private let minimumRefreshIndicatorDuration: TimeInterval

    // MARK: - Private state

    /// 編集モードを抜けた時刻。直後の再入を防ぐ（「完了」タップと長押し・ドラッグ開始の競合対策）。
    @ObservationIgnored private var lastEditModeExitedAt: Date?
    @ObservationIgnored private var pollingTask: Task<Void, Never>?

    private static let tutorialCompletedKey = "tutorial.firstRun.completed"
    private static let editModeReenterCooldown: TimeInterval = 0.6

    /// - Parameters:
    ///   - repositoryPollingInterval: 標準カレンダーからの取り込みを画面へ反映するために、保存済みの予定を読み直す間隔。nil なら読み直さない。
    init(
        repository: TimelineRepository,
        notificationRepository: TimelineNotificationRepository,
        liveActivityRepository: LiveActivityRepository,
        localDefaults: UserDefaults,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init,
        repositoryPollingInterval: Duration? = .seconds(10),
        minimumRefreshIndicatorDuration: TimeInterval = 1.0
    ) {
        self.repository = repository
        self.notificationRepository = notificationRepository
        self.liveActivityRepository = liveActivityRepository
        self.localDefaults = localDefaults
        self.editUseCase = TimelineItemEditUseCase(calendar: calendar)
        self.now = now
        self.minimumRefreshIndicatorDuration = minimumRefreshIndicatorDuration

        var state = TimelineViewState(selectedDate: calendar.startOfDay(for: now()))
        state.items = repository.fetchItems()
        state.isLiveActivitySyncPending = liveActivityRepository.isSyncPending
        self.state = state

        notificationRepository.rescheduleAll(items: state.items)
        if let repositoryPollingInterval {
            startPollingRepository(every: repositoryPollingInterval)
        }
    }

    // MARK: - Screen からの通知（ライフサイクル・シート）

    func onAppear() {
        startFirstRunTutorialIfNeeded()
    }

    func headerHeightDidChange(_ height: CGFloat) {
        guard state.headerHeight != height else { return }
        state.headerHeight = height
    }

    /// アプリが前面に戻った。Live Activity の表示が古くなっていれば直す。
    func sceneDidBecomeActive() async {
        await liveActivityRepository.refreshIfOverdue()
    }

    func dismissSheet() {
        state.sheet = nil
    }

    /// 作成シートの「作成」。開始・終了の指定があればタイムラインへ、無ければ Stock へ追加する。
    func createTask(
        title: String,
        durationMinutes: Int,
        priority: TaskPriority,
        startDate: Date?,
        endDate: Date?
    ) {
        state.sheet = nil
        guard let creation = editUseCase.create(
            title: title,
            durationMinutes: durationMinutes,
            priority: priority,
            startDate: startDate,
            endDate: endDate,
            in: state.items
        ) else { return }

        commit(creation.items)
        AnalyticsClient.logTaskCreate(
            placement: creation.placement == .timeline ? "timeline" : "stock",
            durationMinutes: creation.createdItem.durationMinutes,
            priority: priority.displayName
        )
    }

    /// 編集シートの「保存」。
    func updateTask(id: UUID, title: String, durationMinutes: Int, priority: TaskPriority) {
        state.sheet = nil
        guard let items = editUseCase.update(
            itemID: id,
            title: title,
            durationMinutes: durationMinutes,
            priority: priority,
            in: state.items
        ) else { return }
        commit(items)
    }

    /// 編集シートの「削除」。標準カレンダーに同期済みのイベントも削除される。
    func deleteTask(id: UUID) {
        state.sheet = nil
        repository.deleteItem(id: id)
        setItems(repository.fetchItems())
        notificationRepository.rescheduleAll(items: state.items)
        markLiveActivitySyncPending()
        AnalyticsClient.log(AnalyticsClient.Event.taskDelete)
    }

    // MARK: - タブバーからの通知

    /// 表示中のタイムラインタブをもう一度タップした。今日以外を表示中なら今日へ戻り、現在時刻へスクロールする。
    func timelineTabDidReselect() {
        let today = editUseCase.calendar.startOfDay(for: now())
        if state.selectedDate != today {
            state.selectedDate = today
        }
        state.scrollToNowRequestID = UUID()
    }

    /// タブバー右端のボタン（編集中は「完了」、それ以外は「更新」）をタップした。
    ///
    /// 編集モードを抜け、未反映の変更があれば Live Activity へ反映する。
    /// チュートリアルの最終ステップでは、未反映の変更が無くても反映してチュートリアルを終える。
    func trailingActionDidTap() async {
        let isTutorialFinalStep = state.tutorialStep == .confirmComplete
        if state.isEditing {
            exitEditMode()
        } else if state.isLiveActivityRefreshing {
            return
        }

        let needsSync = isTutorialFinalStep
            || state.isLiveActivitySyncPending
            || liveActivityRepository.isSyncPending
        if needsSync, !state.isLiveActivityRefreshing {
            await syncLiveActivity()
        }
        if isTutorialFinalStep {
            await finishFirstRunTutorial(skipped: false)
        }
    }

    // MARK: - TimelineDelegate: 日付・表示

    func timelineDidSelectDate(_ date: Date) {
        let day = editUseCase.calendar.startOfDay(for: date)
        guard state.selectedDate != day else { return }
        state.selectedDate = day
    }

    func timelineDidTapDateLabel() {
        state.sheet = .datePicker
    }

    func timelineDidPinch(by factor: CGFloat) {
        state.layout.zoom(by: factor)
    }

    // MARK: - TimelineDelegate: 空き領域（長押しで予定を作成）

    func timelineDidTapEmptyArea() {
        guard state.pendingPlacement?.isAwaitingTitle == true else { return }
        state.pendingPlacement = nil
    }

    func timelineDidBeginLongPress(on date: Date, y: CGFloat) {
        guard let pending = editUseCase.beginPendingPlacement(
            atMinutes: state.layout.minutes(atY: y),
            on: date,
            in: state.items
        ) else { return }
        state.pendingPlacement = pending
    }

    func timelineDidMoveLongPress(on date: Date, y: CGFloat) {
        guard let pending = state.pendingPlacement,
              !pending.isAwaitingTitle,
              editUseCase.calendar.isDate(pending.date, inSameDayAs: date)
        else { return }
        state.pendingPlacement = editUseCase.extendPendingPlacement(
            pending,
            toMinutes: state.layout.minutes(atY: y),
            in: state.items
        )
    }

    func timelineDidEndLongPress() {
        guard var pending = state.pendingPlacement, !pending.isAwaitingTitle else { return }
        guard pending.durationMinutes >= TimelineItemEditUseCase.longPressStepMinutes else {
            state.pendingPlacement = nil
            return
        }
        pending.isAwaitingTitle = true
        state.pendingPlacement = pending
    }

    func timelineDidCancelLongPress() {
        state.pendingPlacement = nil
    }

    func timelineDidSubmitPendingPlacementTitle(_ title: String) {
        guard let pending = state.pendingPlacement else { return }
        state.pendingPlacement = nil
        guard let creation = editUseCase.confirm(pending, title: title, in: state.items) else { return }

        commit(creation.items)
        AnalyticsClient.logTaskCreate(
            placement: "timeline_long_press",
            durationMinutes: pending.durationMinutes,
            priority: creation.createdItem.priority.displayName
        )
        // 作成直後に微調整できるよう編集モードへ入る
        requestEnterEditMode()
    }

    // MARK: - TimelineDelegate: タイムライン上の予定

    func timelineDidLongPressItem(id: UUID) {
        requestEnterEditMode()
    }

    func timelineDidRenameItem(id: UUID, title: String) {
        guard let items = editUseCase.rename(itemID: id, title: title, in: state.items) else { return }
        commit(items)
    }

    func timelineDidDragResizeHandle(itemID: UUID, translation: CGFloat) {
        guard let item = item(id: itemID),
              let preview = editUseCase.resizePreview(
                of: item,
                deltaMinutes: state.layout.minutes(forTranslation: translation),
                fallbackDate: state.selectedDate
              )
        else { return }
        state.resizePreview = preview
    }

    func timelineDidReleaseResizeHandle(itemID: UUID, translation: CGFloat) {
        state.resizePreview = nil
        guard let items = editUseCase.resize(
            itemID: itemID,
            deltaMinutes: state.layout.minutes(forTranslation: translation),
            fallbackDate: state.selectedDate,
            in: state.items
        ) else { return }
        commit(items)
    }

    func timelineDidBeginDraggingItem(id: UUID) {
        state.draggingItemID = id
        if !isInEditModeExitCooldown {
            state.isEditing = true
        }
    }

    // MARK: - TimelineDelegate: タイムラインへのドロップ

    func timelineDidIdentifyDropItem(id: UUID) {
        state.dropItemID = id
    }

    func timelineDidHoverDrop(itemID: UUID, on date: Date, y: CGFloat) {
        guard let item = item(id: itemID) else { return }
        state.dropPreview = editUseCase.dropPreview(
            of: item,
            atMinutes: state.layout.minutes(atY: y),
            on: date
        )
    }

    func timelineDidExitDropArea() {
        state.dropPreview = nil
        state.dropItemID = nil
    }

    func timelineDidDropItem(id: UUID, on date: Date, y: CGFloat) {
        guard let item = item(id: id),
              let items = editUseCase.place(
                itemID: id,
                atMinutes: state.layout.minutes(atY: y),
                on: date,
                in: state.items
              )
        else { return }

        commit(items)
        if item.isInStock {
            // Stock から置いた直後は、そのまま微調整できるよう編集モードへ入る
            requestEnterEditMode()
        }
    }

    func timelineDidFinishDrop() {
        clearDragState()
    }

    // MARK: - TimelineDelegate: Stock

    func timelineDidTapAddTask() {
        state.sheet = .createTask
    }

    func timelineDidTapStockItem(id: UUID) {
        guard let item = item(id: id) else { return }
        state.sheet = .editTask(item)
    }

    func timelineDidBeginDraggingStockItem(id: UUID) {
        state.draggingItemID = id
    }

    func timelineDidEndDraggingStockItem() {
        state.draggingItemID = nil
    }

    func timelineDidMoveStockItem(fromIndex: Int, toOffset: Int) {
        guard let items = editUseCase.moveStockItem(
            fromIndex: fromIndex,
            toOffset: toOffset,
            in: state.items
        ) else { return }
        commit(items)
    }

    func timelineDidDropItemOnStock(id: UUID) {
        guard let item = item(id: id), !item.isInStock,
              let items = editUseCase.returnToStock(itemID: id, in: state.items)
        else { return }
        clearDragState()
        commit(items)
    }

    // MARK: - TimelineDelegate: チュートリアル

    func timelineDidTapSkipTutorial() {
        Task { await finishFirstRunTutorial(skipped: true) }
    }

    // MARK: - 予定の反映

    private func item(id: UUID) -> TimelineItem? {
        state.items.first { $0.id == id }
    }

    /// 画面上の予定を差し替える。チュートリアルの進行と、編集中の予定が消えた場合のシートも合わせて更新する。
    private func setItems(_ items: [TimelineItem]) {
        state.items = items
        advanceTutorialIfTaskPlaced()
        if case .editTask(let editing) = state.sheet, item(id: editing.id) == nil {
            state.sheet = nil
        }
    }

    /// 編集結果を画面と保存先に反映し、通知を登録し直して、Live Activity を「未反映」にする。
    private func commit(_ items: [TimelineItem]) {
        setItems(items)
        repository.saveItems(items)
        notificationRepository.rescheduleAll(items: items)
        markLiveActivitySyncPending()
    }

    private func startPollingRepository(every interval: Duration) {
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                guard let self else { return }
                self.reloadItemsIfChanged()
            }
        }
    }

    private func reloadItemsIfChanged() {
        let stored = repository.fetchItems()
        guard stored != state.items else { return }
        setItems(stored)
        notificationRepository.rescheduleAll(items: stored)
        markLiveActivitySyncPending()
    }

    private func clearDragState() {
        state.dropPreview = nil
        state.dropItemID = nil
        state.draggingItemID = nil
    }

    // MARK: - 編集モード

    private var isInEditModeExitCooldown: Bool {
        guard let lastEditModeExitedAt else { return false }
        return now().timeIntervalSince(lastEditModeExitedAt) < Self.editModeReenterCooldown
    }

    /// 編集モードへ入る。編集モードを抜けた直後（クールダウン中）の要求は無視する。
    private func requestEnterEditMode() {
        let isCoolingDown = isInEditModeExitCooldown
        lastEditModeExitedAt = nil
        guard !isCoolingDown else { return }
        state.isEditing = true
    }

    private func exitEditMode() {
        state.isEditing = false
        state.draggingItemID = nil
        state.dropPreview = nil
        lastEditModeExitedAt = now()
    }

    // MARK: - Live Activity

    private func markLiveActivitySyncPending() {
        liveActivityRepository.markSyncPending()
        state.isLiveActivitySyncPending = liveActivityRepository.isSyncPending
    }

    private func syncLiveActivity() async {
        let startedAt = Date()
        state.isLiveActivityRefreshing = true
        await liveActivityRepository.commitSync()
        state.isLiveActivitySyncPending = liveActivityRepository.isSyncPending
        AnalyticsClient.log(AnalyticsClient.Event.liveActivityRefresh)

        let remaining = minimumRefreshIndicatorDuration - Date().timeIntervalSince(startedAt)
        if remaining > 0 {
            try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
        }
        state.isLiveActivityRefreshing = false
    }

    // MARK: - 初回チュートリアル

    private func startFirstRunTutorialIfNeeded() {
        guard !localDefaults.bool(forKey: Self.tutorialCompletedKey) else { return }
        let didAddPresetTask = addTutorialPresetTaskIfStockIsEmpty()
        state.tutorialStep = .placeTaskAfterNow
        if didAddPresetTask {
            advanceTutorialIfTaskPlaced()
        }
    }

    /// チュートリアルで動かしてもらうタスクを Stock に用意する。
    private func addTutorialPresetTaskIfStockIsEmpty() -> Bool {
        guard state.stockItems.isEmpty else { return false }
        let preset = TimelineItem(title: "はじめてのタスク", durationMinutes: 30, priority: .low)
        setItems(state.items + [preset])
        // Stock への追加だけなので、通知の再登録と Live Activity の「未反映」化は不要。
        repository.saveItems(state.items)
        return true
    }

    /// 「現在時刻より後に予定を置く」ステップの達成を確認し、次のステップへ進める。
    private func advanceTutorialIfTaskPlaced() {
        guard state.tutorialStep == .placeTaskAfterNow else { return }
        let nowMinutes = DayTime.minutesSinceMidnight(of: now(), calendar: editUseCase.calendar)
        let hasPlacedTaskAfterNow = state.items.contains {
            !$0.isInStock && ($0.startMinutes ?? -1) > nowMinutes
        }
        guard hasPlacedTaskAfterNow else { return }
        state.tutorialStep = .confirmComplete
    }

    /// チュートリアルを終える。最後まで進めた場合は、ここで通知の許可を求める。
    private func finishFirstRunTutorial(skipped: Bool) async {
        guard state.tutorialStep != nil else { return }
        state.tutorialStep = nil
        localDefaults.set(true, forKey: Self.tutorialCompletedKey)
        AnalyticsClient.log(
            AnalyticsClient.Event.firstRunComplete,
            parameters: [AnalyticsClient.Param.skipped: skipped]
        )
        guard !skipped else { return }
        await notificationRepository.requestAuthorizationIfNeeded()
    }
}
