//
//  TimelineRepository.swift
//  MAMONAKU
//
//  Created by ryota.saito on 2026/01/25.
//
import Foundation
import EventKit
import RealmSwift

protocol TimelineRepositoryProtocol: AnyObject {
    func fetchItems() -> [TimelineItem]
    func saveItems(_ items: [TimelineItem])
    func addItem(_ item: TimelineItem)
    func updateItem(_ item: TimelineItem)
    func deleteItem(id: UUID)
    func fetchNextItemSummary(referenceDate: Date) -> TimelineNextItemSummary?
    func deleteItemAndEvent(id: UUID)
}

final class TimelineRepository: TimelineRepositoryProtocol {
    private let storageKey = "timeline_items"
    private let nextItemKey = "timeline_next_item"
    private let calendarSyncEnabledKey = "calendar_sync_enabled"
    private let subscriptionStateKey = "subscription_is_subscribed"
    private let appGroupID = "group.sairyo.MAMONAKU"
    private let userDefaults: UserDefaults
    private let realmConfig: Realm.Configuration
    private let eventStore = EKEventStore()
    private let calendarSyncQueue = DispatchQueue(label: "MAMONAKU.CalendarSync")
    private var calendarObserver: NSObjectProtocol?
    private var calendarSyncTimer: DispatchSourceTimer?

    init(userDefaults: UserDefaults? = nil) {
        if let userDefaults {
            self.userDefaults = userDefaults
        } else {
            self.userDefaults = UserDefaults(suiteName: appGroupID) ?? .standard
        }

        let realmURL = Self.realmFileURL(appGroupID: appGroupID)
        if let realmURL {
            print("Realm file URL: \(realmURL)")
        } else {
            print("Realm file URL: nil (using default Realm configuration)")
        }
        let config = Realm.Configuration(
            fileURL: realmURL,
            schemaVersion: 5,
            migrationBlock: { _, oldSchemaVersion in
                if oldSchemaVersion < 2 {
                    // Automatic migration is sufficient for added properties.
                }
                if oldSchemaVersion < 3 {
                    // isCompleted added; default false is applied by Realm.
                }
                if oldSchemaVersion < 4 {
                    // priority added; default 1 (medium) is applied by Realm.
                }
                if oldSchemaVersion < 5 {
                    // isAllDay added; default false is applied by Realm.
                }
            }
        )
        self.realmConfig = config

        migrateUserDefaultsIfNeeded()
        startCalendarChangeObservation()
        startCalendarSyncTimer()
    }

    deinit {
        if let calendarObserver {
            NotificationCenter.default.removeObserver(calendarObserver)
        }
        calendarSyncTimer?.cancel()
        calendarSyncTimer = nil
    }

    func fetchItems() -> [TimelineItem] {
        let realm = realmInstance()
        return Array(realm.objects(RealmTimelineItem.self).sorted(byKeyPath: "sortIndex"))
            .map { $0.toTimelineItem() }
    }

    func saveItems(_ items: [TimelineItem]) {
        let realm = realmInstance()
        let existing = realm.objects(RealmTimelineItem.self)
        let existingEventMap = Dictionary<String, String>(uniqueKeysWithValues: existing.compactMap { item in
            guard let eventIdentifier = item.eventIdentifier else { return nil }
            return (item.id, eventIdentifier)
        })
        let newIDs = Set(items.map { $0.id.uuidString })
        let removedEventIdentifiers = existing
            .filter { !newIDs.contains($0.id) }
            .compactMap { $0.eventIdentifier }

        do {
            try realm.write {
                realm.delete(realm.objects(RealmTimelineItem.self))
                for (index, item) in items.enumerated() {
                    let eventIdentifier = existingEventMap[item.id.uuidString]
                    realm.add(RealmTimelineItem(item: item, sortIndex: index, eventIdentifier: eventIdentifier))
                }
            }
        } catch {
            print("😭保存に失敗しました")
        }

        deleteEvents(identifiers: Array(removedEventIdentifiers))
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
        let realm = realmInstance()
        let idString = id.uuidString
        var eventIdentifier: String?

        do {
            try realm.write {
                if let object = realm.object(ofType: RealmTimelineItem.self, forPrimaryKey: idString) {
                    eventIdentifier = object.eventIdentifier
                    realm.delete(object)
                }
            }
        } catch {
            return
        }

        if let eventIdentifier {
            calendarSyncQueue.async { [weak self] in
                self?.deleteEvents(identifiers: [eventIdentifier])
            }
        }

        let items = fetchItems()
        persistItemsToUserDefaults(items)
        persistNextItemSummary(fetchNextItemSummary(referenceDate: Date()))
    }

    func fetchNextItemSummary(referenceDate: Date = Date()) -> TimelineNextItemSummary? {
        let realm = realmInstance()
        let items = realm.objects(RealmTimelineItem.self)
        return nextItemSummary(after: referenceDate, items: items)
    }

    private static func realmFileURL(appGroupID: String) -> URL? {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            return nil
        }
        return containerURL.appendingPathComponent("MAMONAKU.realm")
    }

    private func migrateUserDefaultsIfNeeded() {
        let realm = realmInstance()
        guard realm.objects(RealmTimelineItem.self).isEmpty else { return }
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

    private func requestCalendarAccessIfNeeded() {
        guard isCalendarSyncEnabled else { return }
        let status = EKEventStore.authorizationStatus(for: .event)
        if status == .authorized || status == .fullAccess {
            calendarSyncQueue.async { [weak self] in
                self?.syncRealmFromCalendar()
                self?.syncCalendarFromRealm()
            }
            return
        }
        guard status == .notDetermined else { return }
        eventStore.requestAccess(to: .event) { [weak self] granted, _ in
            guard granted else { return }
            self?.calendarSyncQueue.async {
                self?.syncRealmFromCalendar()
                self?.syncCalendarFromRealm()
            }
        }
    }

    private func startCalendarChangeObservation() {
        guard isCalendarSyncEnabled else { return }
        calendarObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: eventStore,
            queue: nil
        ) { [weak self] _ in
            self?.calendarSyncQueue.async {
                self?.syncRealmFromCalendar()
            }
        }
    }

    private func startCalendarSyncTimer() {
        guard isCalendarSyncEnabled else { return }
        let timer = DispatchSource.makeTimerSource(queue: calendarSyncQueue)
        timer.schedule(deadline: .now() + 10, repeating: 10)
        timer.setEventHandler { [weak self] in
            self?.syncRealmFromCalendar()
        }
        timer.resume()
        calendarSyncTimer = timer
    }

    private func syncRealmFromCalendar() {
        guard isCalendarSyncEnabled else { return }
        let status = EKEventStore.authorizationStatus(for: .event)
        guard status == .authorized || status == .fullAccess else { return }
        guard let calendar = eventStore.defaultCalendarForNewEvents else { return }

        let now = Date()
        let cal = Calendar.current
        let startOfWeek = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? cal.startOfDay(for: now)
        let endOfWeek = cal.date(byAdding: .day, value: 7, to: startOfWeek) ?? now
        let predicate = eventStore.predicateForEvents(withStart: startOfWeek, end: endOfWeek, calendars: [calendar])
        let events = eventStore.events(matching: predicate)

        let realm = realmInstance()
        let existing = realm.objects(RealmTimelineItem.self)
        let existingMap = Dictionary<String, RealmTimelineItem>(uniqueKeysWithValues: existing.compactMap { item in
            guard let eventIdentifier = item.eventIdentifier else { return nil }
            return (eventIdentifier, item)
        })
        let eventIDs = Set(events.map { $0.eventIdentifier })
        let maxSortIndex = existing.map { $0.sortIndex }.max() ?? -1
        var nextSortIndex = maxSortIndex + 1

        do {
            try realm.write {
                for item in existing where item.eventIdentifier != nil && !eventIDs.contains(item.eventIdentifier ?? "") {
                    realm.delete(item)
                }

                for event in events {
                    if let existingItem = existingMap[event.eventIdentifier] {
                        apply(event: event, to: existingItem)
                    } else {
                        let newItem = RealmTimelineItem(
                            item: TimelineItem(
                                title: event.title,
                                durationMinutes: max(1, Int(event.endDate.timeIntervalSince(event.startDate) / 60)),
                                startMinutes: event.isAllDay ? nil : minutesSinceMidnight(date: event.startDate),
                                dropDate: Calendar.current.startOfDay(for: event.startDate),
                                isAllDay: event.isAllDay
                            ),
                            sortIndex: nextSortIndex,
                            eventIdentifier: event.eventIdentifier
                        )
                        nextSortIndex += 1
                        realm.add(newItem)
                    }
                }
            }
        } catch {
            return
        }
        persistNextItemSummary(fetchNextItemSummary(referenceDate: Date()))
    }

    private func syncCalendarFromRealm() {
        guard isCalendarSyncEnabled else { return }
        let status = EKEventStore.authorizationStatus(for: .event)
        guard status == .authorized || status == .fullAccess else { return }
        guard let calendar = eventStore.defaultCalendarForNewEvents else { return }

        let realm = realmInstance()
        let items = realm.objects(RealmTimelineItem.self).sorted(byKeyPath: "sortIndex")
        var updates: [(RealmTimelineItem, String?)] = []

        for item in items {
            guard let dropDate = item.dropDate else {
                if let eventIdentifier = item.eventIdentifier,
                   let event = eventStore.event(withIdentifier: eventIdentifier) {
                    try? eventStore.remove(event, span: .thisEvent)
                }
                updates.append((item, nil))
                continue
            }

            guard !item.isAllDay else { continue }

            guard let startMinutes = item.startMinutes else {
                if let eventIdentifier = item.eventIdentifier,
                   let event = eventStore.event(withIdentifier: eventIdentifier) {
                    try? eventStore.remove(event, span: .thisEvent)
                }
                updates.append((item, nil))
                continue
            }

            let startDate = Calendar.current.date(byAdding: .minute, value: startMinutes, to: dropDate) ?? dropDate
            let endDate = startDate.addingTimeInterval(TimeInterval(item.durationMinutes * 60))

            let event: EKEvent
            if let eventIdentifier = item.eventIdentifier,
               let existing = eventStore.event(withIdentifier: eventIdentifier) {
                event = existing
            } else {
                event = EKEvent(eventStore: eventStore)
                event.calendar = calendar
            }

            event.title = item.title
            event.isAllDay = false
            event.startDate = startDate
            event.endDate = endDate

            try? eventStore.save(event, span: .thisEvent)
            updates.append((item, event.eventIdentifier))
        }

        do {
            try realm.write {
                for (item, identifier) in updates {
                    item.eventIdentifier = identifier
                }
            }
        } catch {
            return
        }
    }

    private func deleteEvents(identifiers: [String]) {
        guard isCalendarSyncEnabled else { return }
        let status = EKEventStore.authorizationStatus(for: .event)
        guard status == .authorized || status == .fullAccess else { return }
        for identifier in identifiers {
            if let event = eventStore.event(withIdentifier: identifier) {
                try? eventStore.remove(event, span: .thisEvent)
            }
        }
    }

    private func apply(event: EKEvent, to item: RealmTimelineItem) {
        let startMinutes = event.isAllDay ? nil : minutesSinceMidnight(date: event.startDate)
        item.title = event.title
        item.startMinutes = startMinutes
        item.dropDate = Calendar.current.startOfDay(for: event.startDate)
        item.durationMinutes = max(1, Int(event.endDate.timeIntervalSince(event.startDate) / 60))
        item.isAllDay = event.isAllDay
        item.eventIdentifier = event.eventIdentifier
    }

    private func minutesSinceMidnight(date: Date) -> Int {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        let h = comps.hour ?? 0
        let m = comps.minute ?? 0
        return (h * 60) + m
    }

    /// 標準カレンダー同期はサブスクリプション加入時のみ有効
    private var isCalendarSyncEnabled: Bool {
        let syncPreferred = userDefaults.object(forKey: calendarSyncEnabledKey) == nil
            ? true
            : userDefaults.bool(forKey: calendarSyncEnabledKey)
        let subscribed = (userDefaults.object(forKey: subscriptionStateKey) as? Bool) ?? false
        return syncPreferred && subscribed
    }

    private func nextItemSummary(after date: Date, items: Results<RealmTimelineItem>) -> TimelineNextItemSummary? {
        let nowSeconds = secondsSinceMidnight(date: date)
        let startMinutes = Int(ceil(Double(nowSeconds) / 60.0))
        let todayItems = items.filter { item in
            guard let dropDate = item.dropDate else { return false }
            return Calendar.current.isDateInToday(dropDate)
        }
        let candidates: [(RealmTimelineItem, Int)] = todayItems.compactMap { item in
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

    private func realmInstance() -> Realm {
        (try? Realm(configuration: realmConfig)) ?? (try! Realm())
    }
}

struct TimelineNextItemSummary: Codable, Equatable {
    let title: String
    let startDate: Date?
}

final class RealmTimelineItem: Object {
    @Persisted(primaryKey: true) var id: String
    @Persisted var title: String = ""
    @Persisted var durationMinutes: Int = 0
    @Persisted var startMinutes: Int?
    @Persisted var dropDate: Date?
    @Persisted var sortIndex: Int = 0
    @Persisted var eventIdentifier: String?
    @Persisted var isCompleted: Bool = false
    @Persisted var priority: Int = 1
    @Persisted var isAllDay: Bool = false

    convenience init(item: TimelineItem, sortIndex: Int, eventIdentifier: String? = nil) {
        self.init()
        self.id = item.id.uuidString
        self.title = item.title
        self.durationMinutes = item.durationMinutes
        self.startMinutes = item.startMinutes
        self.dropDate = item.dropDate
        self.sortIndex = sortIndex
        self.eventIdentifier = eventIdentifier
        self.isCompleted = item.isCompleted
        self.priority = item.priority.rawValue
        self.isAllDay = item.isAllDay
    }

    func toTimelineItem() -> TimelineItem {
        TimelineItem(
            id: UUID(uuidString: id) ?? UUID(),
            title: title,
            durationMinutes: durationMinutes,
            startMinutes: startMinutes,
            dropDate: dropDate,
            isCompleted: isCompleted,
            priority: TaskPriority(rawValue: priority) ?? .medium,
            isAllDay: isAllDay
        )
    }
}
