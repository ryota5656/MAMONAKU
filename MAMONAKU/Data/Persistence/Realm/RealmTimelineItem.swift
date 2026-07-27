//
//  RealmTimelineItem.swift
//  MAMONAKU
//

import Foundation
import RealmSwift

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
