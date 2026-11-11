import EventKit
import Foundation

/// 予定（Realm）と標準カレンダー（EventKit）の双方向同期。
///
/// 同期は「設定でオン」かつ「PLUS 加入中」（`AppSettingsClient.isCalendarSyncEnabled`）の間だけ動く。
/// - カレンダー → Realm: カレンダーの変更通知と 10 秒ごとのタイマーで取り込む。
/// - Realm → カレンダー: 予定の保存時（`exportItemsToCalendar`）と上記の同期時に書き出す。
///
/// 設定や加入状態は UserDefaults の変更通知と 2 秒ごとの確認で検知し、同期の開始 / 停止を切り替える。
///
/// 同期処理は専用の直列キューで動かす。コンパイラが検証できない形でスレッドをまたぐため `@unchecked Sendable`。
nonisolated final class CalendarSyncClient: @unchecked Sendable {
    private let realmClient: TimelineRealmClient
    private let settings: AppSettingsClient
    private let eventStore = EKEventStore()
    private let queue = DispatchQueue(label: "MAMONAKU.CalendarSync")

    private var eventStoreObserver: NSObjectProtocol?
    private var defaultsObserver: NSObjectProtocol?
    private var syncTimer: DispatchSourceTimer?
    private var stateTimer: DispatchSourceTimer?
    private var isActive = false

    /// カレンダーからの取り込みで Realm を更新した直後に、同期キュー上で呼ばれる。
    var onItemsImported: (() -> Void)?

    init(realmClient: TimelineRealmClient, settings: AppSettingsClient) {
        self.realmClient = realmClient
        self.settings = settings
    }

    deinit {
        if let eventStoreObserver {
            NotificationCenter.default.removeObserver(eventStoreObserver)
        }
        if let defaultsObserver {
            NotificationCenter.default.removeObserver(defaultsObserver)
        }
        syncTimer?.cancel()
        stateTimer?.cancel()
    }

    // MARK: - 開始 / 設定変更

    /// 設定の監視を始め、同期が有効なら初回同期を行う。
    func start() {
        observeSettings()
        refreshState(runInitialSync: true)
    }

    /// 標準カレンダーへのフルアクセスを確認する。未決定なら許可ダイアログを出す。
    func requestFullAccess() async -> Bool {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess:
            return true
        case .notDetermined:
            return (try? await eventStore.requestFullAccessToEvents()) ?? false
        default:
            return false
        }
    }

    /// ユーザーが同期設定を切り替えたときに呼ぶ。オンにした場合は権限確認と初回同期まで行う。
    func preferenceDidChange(isEnabled: Bool) {
        queue.async { [weak self] in
            self?.refreshState(runInitialSync: isEnabled)
        }
    }

    // MARK: - Realm → カレンダー

    /// Realm の予定をカレンダーへ書き出す（作成・更新・Stock に戻した予定のイベント削除）。
    func exportItemsToCalendar() {
        guard settings.isCalendarSyncEnabled, hasFullCalendarAccess,
              let calendar = eventStore.defaultCalendarForNewEvents
        else { return }

        var updates: [(id: String, eventIdentifier: String?)] = []
        for record in realmClient.fetchStoredRecordsSorted() {
            guard let range = eventDateRange(for: record) else {
                // 未配置（Stock）になった予定は、同期済みイベントがあれば消す。
                removeEvent(identifier: record.eventIdentifier)
                updates.append((record.id, nil))
                continue
            }

            let event: EKEvent
            let needsSave: Bool
            if let identifier = record.eventIdentifier, let existing = eventStore.event(withIdentifier: identifier) {
                event = existing
                needsSave = existing.title != record.title
                    || existing.isAllDay != record.isAllDay
                    || abs(existing.startDate.timeIntervalSince(range.start)) >= 1
                    || abs(existing.endDate.timeIntervalSince(range.end)) >= 1
            } else {
                event = EKEvent(eventStore: eventStore)
                event.calendar = calendar
                needsSave = true
            }

            event.title = record.title
            event.isAllDay = record.isAllDay
            event.startDate = range.start
            event.endDate = range.end
            if needsSave {
                try? eventStore.save(event, span: .thisEvent)
            }
            updates.append((record.id, event.eventIdentifier))
        }

        realmClient.updateEventIdentifiers(updates)
    }

    /// 削除された予定に紐づくイベントをカレンダーから消す。
    func deleteEvents(identifiers: [String]) {
        guard settings.isCalendarSyncEnabled, hasFullCalendarAccess else { return }
        identifiers.forEach { removeEvent(identifier: $0) }
    }

    /// `deleteEvents` を同期キューで行う。
    func deleteEventsInBackground(identifiers: [String]) {
        queue.async { [weak self] in
            self?.deleteEvents(identifiers: identifiers)
        }
    }

    // MARK: - 同期状態の切り替え

    private func observeSettings() {
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: settings.defaults,
            queue: nil
        ) { [weak self] _ in
            self?.queue.async {
                self?.refreshState()
            }
        }
        stateTimer = makeRepeatingTimer(interval: 2) { [weak self] in
            self?.refreshState()
        }
    }

    private func refreshState(runInitialSync: Bool = false) {
        guard settings.isCalendarSyncEnabled else {
            deactivate()
            return
        }
        if !isActive {
            isActive = true
            observeEventStoreChanges()
            startSyncTimer()
        }
        if runInitialSync {
            requestAccessThenSync()
        }
    }

    private func deactivate() {
        guard isActive else { return }
        if let eventStoreObserver {
            NotificationCenter.default.removeObserver(eventStoreObserver)
            self.eventStoreObserver = nil
        }
        syncTimer?.cancel()
        syncTimer = nil
        isActive = false
    }

    private func observeEventStoreChanges() {
        guard eventStoreObserver == nil else { return }
        eventStoreObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: eventStore,
            queue: nil
        ) { [weak self] _ in
            self?.queue.async {
                self?.syncBothDirections()
            }
        }
    }

    private func startSyncTimer() {
        guard syncTimer == nil else { return }
        syncTimer = makeRepeatingTimer(interval: 10) { [weak self] in
            self?.syncBothDirections()
        }
    }

    private func makeRepeatingTimer(interval: Int, handler: @escaping () -> Void) -> DispatchSourceTimer {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + .seconds(interval), repeating: .seconds(interval))
        timer.setEventHandler(handler: handler)
        timer.resume()
        return timer
    }

    private func requestAccessThenSync() {
        if hasFullCalendarAccess {
            queue.async { [weak self] in
                self?.syncBothDirections()
            }
            return
        }
        guard EKEventStore.authorizationStatus(for: .event) == .notDetermined else { return }
        eventStore.requestFullAccessToEvents { [weak self] granted, _ in
            guard granted else { return }
            self?.queue.async {
                self?.syncBothDirections()
            }
        }
    }

    // MARK: - カレンダー → Realm

    private func syncBothDirections() {
        guard settings.isCalendarSyncEnabled else { return }
        importEventsFromCalendar()
        exportItemsToCalendar()
    }

    private func importEventsFromCalendar() {
        guard hasFullCalendarAccess, let calendar = eventStore.defaultCalendarForNewEvents else { return }

        let window = syncWindow()
        let predicate = eventStore.predicateForEvents(withStart: window.start, end: window.end, calendars: [calendar])
        let imports = eventStore.events(matching: predicate).compactMap { event -> CalendarEventImport? in
            guard let eventIdentifier = event.eventIdentifier else { return nil }
            return CalendarEventImport(
                eventIdentifier: eventIdentifier,
                title: event.title,
                startDate: event.startDate,
                endDate: event.endDate,
                isAllDay: event.isAllDay
            )
        }

        realmClient.importCalendarEvents(imports, in: window)
        onItemsImported?()
    }

    // MARK: - Helpers

    private var hasFullCalendarAccess: Bool {
        EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }

    /// 同期対象の期間（今日の前後 1 年）。
    private func syncWindow(referenceDate: Date = Date()) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: referenceDate)
        let start = calendar.date(byAdding: .year, value: -1, to: startOfToday) ?? startOfToday
        let end = calendar.date(byAdding: .year, value: 1, to: startOfToday) ?? startOfToday
        return (start, end)
    }

    /// 予定に対応するイベントの開始・終了。未配置（日付なし / 開始時刻なし）の予定は nil。
    private func eventDateRange(for record: TimelineStoredRecord) -> (start: Date, end: Date)? {
        guard let dropDate = record.dropDate else { return nil }
        let calendar = Calendar.current
        if record.isAllDay {
            let end = calendar.date(byAdding: .day, value: 1, to: dropDate) ?? dropDate.addingTimeInterval(24 * 60 * 60)
            return (dropDate, end)
        }
        guard let startMinutes = record.startMinutes else { return nil }
        let start = calendar.date(byAdding: .minute, value: startMinutes, to: dropDate) ?? dropDate
        return (start, start.addingTimeInterval(TimeInterval(record.durationMinutes * 60)))
    }

    private func removeEvent(identifier: String?) {
        guard let identifier, let event = eventStore.event(withIdentifier: identifier) else { return }
        try? eventStore.remove(event, span: .thisEvent)
    }
}
