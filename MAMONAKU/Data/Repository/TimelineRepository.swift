//
//  TimelineRepository.swift
//  MAMONAKU
//
//  Created by ryota.saito on 2026/01/25.
//
import Foundation
import EventKit

protocol TimelineRepositoryProtocol: AnyObject {
    func fetchItems() -> [TimelineItem]
    func saveItems(_ items: [TimelineItem])
    func addItem(_ item: TimelineItem)
    func updateItem(_ item: TimelineItem)
    func deleteItem(id: UUID)
    func fetchNextItemSummary(referenceDate: Date) -> TimelineNextItemSummary?
    func deleteItemAndEvent(id: UUID)
    func setCalendarSyncEnabled(_ enabled: Bool)
}

final class TimelineRepository: TimelineRepositoryProtocol {
    private let storageKey = "timeline_items"
    private let nextItemKey = "timeline_next_item"
    private let calendarSyncEnabledKey = "calendar_sync_enabled"
    private let subscriptionStateKey = "subscription_is_subscribed"
    private let appGroupID = "group.sairyo.MAMONAKU"
    private let userDefaults: UserDefaults
    private let realmStore: TimelineRealmStore
    private let eventStore = EKEventStore()
    private let calendarSyncQueue = DispatchQueue(label: "MAMONAKU.CalendarSync")
    private var calendarObserver: NSObjectProtocol?
    private var calendarSyncTimer: DispatchSourceTimer?
    private var calendarSyncStateTimer: DispatchSourceTimer?
    private var userDefaultsObserver: NSObjectProtocol?
    private var isCalendarSyncActive = false

    init(userDefaults: UserDefaults? = nil, realmStore: TimelineRealmStore = TimelineRealmStore()) {
        if let userDefaults {
            self.userDefaults = userDefaults
        } else {
            self.userDefaults = UserDefaults(suiteName: appGroupID) ?? .standard
        }
        self.realmStore = realmStore

        migrateUserDefaultsIfNeeded()
        startCalendarSyncStateObservation()
        refreshCalendarSyncState(runInitialSync: true)
    }

    deinit {
        if let calendarObserver {
            NotificationCenter.default.removeObserver(calendarObserver)
        }
        if let userDefaultsObserver {
            NotificationCenter.default.removeObserver(userDefaultsObserver)
        }
        calendarSyncTimer?.cancel()
        calendarSyncTimer = nil
        calendarSyncStateTimer?.cancel()
        calendarSyncStateTimer = nil
    }

    func fetchItems() -> [TimelineItem] {
        realmStore.fetchItems()
    }

    func saveItems(_ items: [TimelineItem]) {
        let removedEventIdentifiers = realmStore.replaceAll(with: items)
        deleteEvents(identifiers: removedEventIdentifiers)
        syncCalendarFromRealm()
        persistItemsToUserDefaults(items)
        persistNextItemSummary(fetchNextItemSummary(referenceDate: Date()))
    }

    func addItem(_ item: TimelineItem) {
        var items = fetchItems()
        items.append(item)
        saveItems(items)
    }

    func updateItem(_ item: TimelineItem) {
        var items = fetchItems()
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        } else {
            items.append(item)
        }
        saveItems(items)
    }

    func deleteItem(id: UUID) {
        var items = fetchItems()
        items.removeAll { $0.id == id }
        saveItems(items)
    }

    func deleteItemAndEvent(id: UUID) {
        let result = realmStore.deleteItem(id: id)
        guard result.success else { return }

        if let eventIdentifier = result.eventIdentifier {
            calendarSyncQueue.async { [weak self] in
                self?.deleteEvents(identifiers: [eventIdentifier])
            }
        }

        let items = fetchItems()
        persistItemsToUserDefaults(items)
        persistNextItemSummary(fetchNextItemSummary(referenceDate: Date()))
    }

    func setCalendarSyncEnabled(_ enabled: Bool) {
        userDefaults.set(enabled, forKey: calendarSyncEnabledKey)
        calendarSyncQueue.async { [weak self] in
            self?.refreshCalendarSyncState(runInitialSync: enabled)
        }
    }

    func fetchNextItemSummary(referenceDate: Date = Date()) -> TimelineNextItemSummary? {
        nextItemSummary(after: referenceDate, items: fetchItems())
    }

    private func migrateUserDefaultsIfNeeded() {
        guard realmStore.isEmpty() else { return }
        guard let data = userDefaults.data(forKey: storageKey) else { return }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let items = try decoder.decode([TimelineItem].self, from: data)
            saveItems(items)
        } catch {
            return
        }
    }

    private func persistItemsToUserDefaults(_ items: [TimelineItem]) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(items)
            userDefaults.set(data, forKey: storageKey)
        } catch {
            return
        }
    }

    private func persistNextItemSummary(_ summary: TimelineNextItemSummary?) {
        guard let summary else {
            userDefaults.removeObject(forKey: nextItemKey)
            return
        }
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(summary)
            userDefaults.set(data, forKey: nextItemKey)
        } catch {
            return
        }
    }

    private func startCalendarSyncStateObservation() {
        userDefaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: userDefaults,
            queue: nil
        ) { [weak self] _ in
            self?.calendarSyncQueue.async {
                self?.refreshCalendarSyncState()
            }
        }

        let timer = DispatchSource.makeTimerSource(queue: calendarSyncQueue)
        timer.schedule(deadline: .now() + 2, repeating: 2)
        timer.setEventHandler { [weak self] in
            self?.refreshCalendarSyncState()
        }
        timer.resume()
        calendarSyncStateTimer = timer
    }

    private func refreshCalendarSyncState(runInitialSync: Bool = false) {
        guard isCalendarSyncEnabled else {
            stopCalendarSyncIfNeeded()
            return
        }

        if !isCalendarSyncActive {
            isCalendarSyncActive = true
            startCalendarChangeObservation()
            startCalendarSyncTimer()
        }

        if runInitialSync {
            requestCalendarAccessIfNeeded()
        }
    }

    private func stopCalendarSyncIfNeeded() {
        guard isCalendarSyncActive else { return }
        if let calendarObserver {
            NotificationCenter.default.removeObserver(calendarObserver)
            self.calendarObserver = nil
        }
        calendarSyncTimer?.cancel()
        calendarSyncTimer = nil
        isCalendarSyncActive = false
    }

    private func requestCalendarAccessIfNeeded() {
        guard isCalendarSyncEnabled else { return }
        let status = EKEventStore.authorizationStatus(for: .event)
        if hasFullCalendarAccess(status) {
            calendarSyncQueue.async { [weak self] in
                self?.performFullCalendarSync()
            }
            return
        }
        guard status == .notDetermined else { return }

        if #available(iOS 17.0, *) {
            eventStore.requestFullAccessToEvents { [weak self] granted, _ in
                guard granted else { return }
                self?.calendarSyncQueue.async {
                    self?.performFullCalendarSync()
                }
            }
        } else {
            eventStore.requestAccess(to: .event) { [weak self] granted, _ in
                guard granted else { return }
                self?.calendarSyncQueue.async {
                    self?.performFullCalendarSync()
                }
            }
        }
    }

    private func startCalendarChangeObservation() {
        guard isCalendarSyncEnabled, calendarObserver == nil else { return }
        calendarObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: eventStore,
            queue: nil
        ) { [weak self] _ in
            self?.calendarSyncQueue.async {
                self?.performFullCalendarSync()
            }
        }
    }

    private func startCalendarSyncTimer() {
        guard isCalendarSyncEnabled, calendarSyncTimer == nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: calendarSyncQueue)
        timer.schedule(deadline: .now() + 10, repeating: 10)
        timer.setEventHandler { [weak self] in
            self?.performFullCalendarSync()
        }
        timer.resume()
        calendarSyncTimer = timer
    }

    private func performFullCalendarSync() {
        guard isCalendarSyncEnabled else { return }
        syncRealmFromCalendar()
        syncCalendarFromRealm()
    }

    private func syncRealmFromCalendar() {
        guard isCalendarSyncEnabled else { return }
        let status = EKEventStore.authorizationStatus(for: .event)
        guard hasFullCalendarAccess(status) else { return }
        guard let calendar = eventStore.defaultCalendarForNewEvents else { return }

        let window = calendarSyncWindow()
        let predicate = eventStore.predicateForEvents(withStart: window.start, end: window.end, calendars: [calendar])
        let events = eventStore.events(matching: predicate)
        let imports = events.compactMap { event -> CalendarEventImport? in
            guard let eventIdentifier = event.eventIdentifier else { return nil }
            return CalendarEventImport(
                eventIdentifier: eventIdentifier,
                title: event.title,
                startDate: event.startDate,
                endDate: event.endDate,
                isAllDay: event.isAllDay
            )
        }

        realmStore.importCalendarEvents(imports, in: window)
        let items = fetchItems()
        persistItemsToUserDefaults(items)
        persistNextItemSummary(fetchNextItemSummary(referenceDate: Date()))
    }

    private func syncCalendarFromRealm() {
        guard isCalendarSyncEnabled else { return }
        let status = EKEventStore.authorizationStatus(for: .event)
        guard hasFullCalendarAccess(status) else { return }
        guard let calendar = eventStore.defaultCalendarForNewEvents else { return }

        let records = realmStore.fetchStoredRecordsSorted()
        var updates: [(id: String, eventIdentifier: String?)] = []

        for record in records {
            guard let dropDate = record.dropDate else {
                if let eventIdentifier = record.eventIdentifier,
                   let event = eventStore.event(withIdentifier: eventIdentifier) {
                    try? eventStore.remove(event, span: .thisEvent)
                }
                updates.append((record.id, nil))
                continue
            }

            let startDate: Date
            let endDate: Date
            if record.isAllDay {
                startDate = dropDate
                endDate = Calendar.current.date(byAdding: .day, value: 1, to: dropDate) ?? dropDate.addingTimeInterval(24 * 60 * 60)
            } else if let startMinutes = record.startMinutes {
                startDate = Calendar.current.date(byAdding: .minute, value: startMinutes, to: dropDate) ?? dropDate
                endDate = startDate.addingTimeInterval(TimeInterval(record.durationMinutes * 60))
            } else {
                if let eventIdentifier = record.eventIdentifier,
                   let event = eventStore.event(withIdentifier: eventIdentifier) {
                    try? eventStore.remove(event, span: .thisEvent)
                }
                updates.append((record.id, nil))
                continue
            }

            let event: EKEvent
            let shouldSaveEvent: Bool
            if let eventIdentifier = record.eventIdentifier,
               let existing = eventStore.event(withIdentifier: eventIdentifier) {
                event = existing
                shouldSaveEvent = eventNeedsSave(event, title: record.title, isAllDay: record.isAllDay, startDate: startDate, endDate: endDate)
            } else {
                event = EKEvent(eventStore: eventStore)
                event.calendar = calendar
                shouldSaveEvent = true
            }

            event.title = record.title
            event.isAllDay = record.isAllDay
            event.startDate = startDate
            event.endDate = endDate

            if shouldSaveEvent {
                try? eventStore.save(event, span: .thisEvent)
            }
            updates.append((record.id, event.eventIdentifier))
        }

        realmStore.updateEventIdentifiers(updates)
    }

    private func deleteEvents(identifiers: [String]) {
        guard isCalendarSyncEnabled else { return }
        let status = EKEventStore.authorizationStatus(for: .event)
        guard hasFullCalendarAccess(status) else { return }
        for identifier in identifiers {
            if let event = eventStore.event(withIdentifier: identifier) {
                try? eventStore.remove(event, span: .thisEvent)
            }
        }
    }

    private func hasFullCalendarAccess(_ status: EKAuthorizationStatus) -> Bool {
        if status == .authorized {
            return true
        }
        if #available(iOS 17.0, *) {
            return status == .fullAccess
        }
        return false
    }

    private func calendarSyncWindow(referenceDate: Date = Date()) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: referenceDate)
        let start = calendar.date(byAdding: .year, value: -1, to: startOfToday) ?? startOfToday
        let end = calendar.date(byAdding: .year, value: 1, to: startOfToday) ?? startOfToday
        return (start, end)
    }

    private func eventNeedsSave(
        _ event: EKEvent,
        title: String,
        isAllDay: Bool,
        startDate: Date,
        endDate: Date
    ) -> Bool {
        event.title != title
            || event.isAllDay != isAllDay
            || abs(event.startDate.timeIntervalSince(startDate)) >= 1
            || abs(event.endDate.timeIntervalSince(endDate)) >= 1
    }

    /// 標準カレンダー同期はサブスクリプション加入時のみ有効
    private var isCalendarSyncEnabled: Bool {
        let syncPreferred = userDefaults.object(forKey: calendarSyncEnabledKey) == nil
            ? false
            : userDefaults.bool(forKey: calendarSyncEnabledKey)
        let subscribed = (userDefaults.object(forKey: subscriptionStateKey) as? Bool) ?? false
        return syncPreferred && subscribed
    }

    private func nextItemSummary(after date: Date, items: [TimelineItem]) -> TimelineNextItemSummary? {
        let nowSeconds = secondsSinceMidnight(date: date)
        let startMinutes = Int(ceil(Double(nowSeconds) / 60.0))
        let todayItems = items.filter { item in
            guard let dropDate = item.dropDate else { return false }
            return Calendar.current.isDateInToday(dropDate)
        }
        let candidates: [(TimelineItem, Int)] = todayItems.compactMap { item in
            guard let minutes = item.startMinutes else { return nil }
            return (item, minutes)
        }
        guard let next = candidates
            .filter({ $0.1 > startMinutes })
            .min(by: { $0.1 < $1.1 })?.0
        else {
            return nil
        }
        let startDate = Calendar.current.startOfDay(for: date)
        let nextStartDate = Calendar.current.date(byAdding: .minute, value: next.startMinutes ?? 0, to: startDate)
        return TimelineNextItemSummary(
            title: next.title,
            startDate: nextStartDate
        )
    }

    private func secondsSinceMidnight(date: Date) -> Int {
        let comps = Calendar.current.dateComponents([.hour, .minute, .second], from: date)
        let h = comps.hour ?? 0
        let m = comps.minute ?? 0
        let s = comps.second ?? 0
        return (h * 3600) + (m * 60) + s
    }
}

struct TimelineNextItemSummary: Codable, Equatable {
    let title: String
    let startDate: Date?
}
