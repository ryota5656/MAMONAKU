//
//  TimelineRealmStore.swift
//  MAMONAKU
//

import Foundation
import RealmSwift

struct TimelineStoredRecord {
    let id: String
    var title: String
    var durationMinutes: Int
    var startMinutes: Int?
    var dropDate: Date?
    var sortIndex: Int
    var eventIdentifier: String?
    var isAllDay: Bool
}

struct CalendarEventImport {
    let eventIdentifier: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
}

final class TimelineRealmStore {
    private let realmProvider: RealmProvider

    init(realmProvider: RealmProvider = RealmProvider()) {
        self.realmProvider = realmProvider
    }

    func fetchItems() -> [TimelineItem] {
        let realm = realmProvider.makeRealm()
        return Array(realm.objects(RealmTimelineItem.self).sorted(byKeyPath: "sortIndex"))
            .map { $0.toTimelineItem() }
    }

    func isEmpty() -> Bool {
        let realm = realmProvider.makeRealm()
        return realm.objects(RealmTimelineItem.self).isEmpty
    }

    func replaceAll(with items: [TimelineItem]) -> [String] {
        let realm = realmProvider.makeRealm()
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

        return Array(removedEventIdentifiers)
    }

    func deleteItem(id: UUID) -> (success: Bool, eventIdentifier: String?) {
        let realm = realmProvider.makeRealm()
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
            return (success: false, eventIdentifier: nil)
        }

        return (success: true, eventIdentifier: eventIdentifier)
    }

    func fetchStoredRecordsSorted() -> [TimelineStoredRecord] {
        let realm = realmProvider.makeRealm()
        return realm.objects(RealmTimelineItem.self)
            .sorted(byKeyPath: "sortIndex")
            .map { $0.toStoredRecord() }
    }

    func importCalendarEvents(_ events: [CalendarEventImport], in window: (start: Date, end: Date)) {
        let realm = realmProvider.makeRealm()
        let existing = realm.objects(RealmTimelineItem.self)
        var existingMap: [String: RealmTimelineItem] = [:]
        for item in existing {
            guard let eventIdentifier = item.eventIdentifier else { continue }
            existingMap[eventIdentifier] = item
        }
        let eventIDs = Set(events.map { $0.eventIdentifier })
        let maxSortIndex = existing.map { $0.sortIndex }.max() ?? -1
        var nextSortIndex = maxSortIndex + 1

        do {
            let itemsToDelete = existing.filter { item in
                guard let eventIdentifier = item.eventIdentifier else { return false }
                return !eventIDs.contains(eventIdentifier) && Self.shouldDeleteMissingCalendarEvent(item, in: window)
            }

            try realm.write {
                for item in itemsToDelete {
                    realm.delete(item)
                }

                for event in events {
                    if let existingItem = existingMap[event.eventIdentifier] {
                        Self.apply(event: event, to: existingItem)
                    } else {
                        let newItem = RealmTimelineItem(
                            item: TimelineItem(
                                title: event.title,
                                durationMinutes: max(1, Int(event.endDate.timeIntervalSince(event.startDate) / 60)),
                                startMinutes: event.isAllDay ? nil : Self.minutesSinceMidnight(date: event.startDate),
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
    }

    func updateEventIdentifiers(_ updates: [(id: String, eventIdentifier: String?)]) {
        let realm = realmProvider.makeRealm()

        do {
            try realm.write {
                for (id, identifier) in updates {
                    guard let item = realm.object(ofType: RealmTimelineItem.self, forPrimaryKey: id) else { continue }
                    item.eventIdentifier = identifier
                }
            }
        } catch {
            return
        }
    }

    private static func apply(event: CalendarEventImport, to item: RealmTimelineItem) {
        let startMinutes = event.isAllDay ? nil : minutesSinceMidnight(date: event.startDate)
        item.title = event.title
        item.startMinutes = startMinutes
        item.dropDate = Calendar.current.startOfDay(for: event.startDate)
        item.durationMinutes = max(1, Int(event.endDate.timeIntervalSince(event.startDate) / 60))
        item.isAllDay = event.isAllDay
        item.eventIdentifier = event.eventIdentifier
    }

    private static func shouldDeleteMissingCalendarEvent(_ item: RealmTimelineItem, in window: (start: Date, end: Date)) -> Bool {
        guard let dropDate = item.dropDate else { return true }
        return dropDate >= window.start && dropDate < window.end
    }

    private static func minutesSinceMidnight(date: Date) -> Int {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        let h = comps.hour ?? 0
        let m = comps.minute ?? 0
        return (h * 60) + m
    }
}

private extension RealmTimelineItem {
    func toStoredRecord() -> TimelineStoredRecord {
        TimelineStoredRecord(
            id: id,
            title: title,
            durationMinutes: durationMinutes,
            startMinutes: startMinutes,
            dropDate: dropDate,
            sortIndex: sortIndex,
            eventIdentifier: eventIdentifier,
            isAllDay: isAllDay
        )
    }
}
