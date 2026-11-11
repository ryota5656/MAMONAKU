import Foundation
import Realm
import RealmSwift

/// ルーティンの Realm 保存形式。各日の予定は `RealmTimelineItem.routineID` でここを指す。
nonisolated final class RealmTimelineRoutine: Object {
    @Persisted(primaryKey: true) var id: String
    @Persisted var title: String = ""
    @Persisted var startMinutes: Int = 0
    @Persisted var durationMinutes: Int = 0
    @Persisted var priority: Int = 1
    @Persisted var weekdays: List<Int>
    @Persisted var startDate: Date = Date()
    @Persisted var endDate: Date = Date()

    convenience init(routine: TimelineRoutine) {
        self.init()
        self.id = routine.id.uuidString
        self.title = routine.title
        self.startMinutes = routine.startMinutes
        self.durationMinutes = routine.durationMinutes
        self.priority = routine.priority.rawValue
        self.weekdays.append(objectsIn: routine.weekdays)
        self.startDate = routine.startDate
        self.endDate = routine.endDate
    }

    func toTimelineRoutine() -> TimelineRoutine {
        TimelineRoutine(
            id: UUID(uuidString: id) ?? UUID(),
            title: title,
            startMinutes: startMinutes,
            durationMinutes: durationMinutes,
            priority: TaskPriority(rawValue: priority) ?? .medium,
            weekdays: Array(weekdays),
            startDate: startDate,
            endDate: endDate
        )
    }
}
