import Foundation

/// タスク作成時に指定する繰り返し（毎日、または固定曜日）。終了日までの該当日をまとめて作る。
nonisolated struct RoutineRepeat: Equatable, Sendable {
    /// `Calendar` の weekday（1 = 日曜 … 7 = 土曜）
    var weekdays: Set<Int>
    /// この日を含む
    var endDate: Date
}

/// 同じ時刻で繰り返す予定の型。各日の予定は通常の `TimelineItem` で、`routineID` でここを指す。
nonisolated struct TimelineRoutine: Identifiable, Equatable, Hashable, Codable, Sendable {
    let id: UUID
    var title: String
    var startMinutes: Int
    var durationMinutes: Int
    var priority: TaskPriority
    /// `Calendar` の weekday。月始まりの順で持つ。
    var weekdays: [Int]
    /// 期間の開始日（その日の 0 時）
    var startDate: Date
    /// 期間の終了日（その日の 0 時、この日を含む）
    var endDate: Date

    init(
        id: UUID = UUID(),
        title: String,
        startMinutes: Int,
        durationMinutes: Int,
        priority: TaskPriority,
        weekdays: [Int],
        startDate: Date,
        endDate: Date
    ) {
        self.id = id
        self.title = title
        self.startMinutes = startMinutes
        self.durationMinutes = durationMinutes
        self.priority = priority
        self.weekdays = weekdays
        self.startDate = startDate
        self.endDate = endDate
    }

    var weekdaySet: Set<Int> { Set(weekdays) }

    func scheduleSummary(calendar: Calendar = .current) -> String {
        let days = RoutineCalendar.summary(for: weekdaySet, calendar: calendar)
        let time = DayTime.rangeText(startMinutes: startMinutes, durationMinutes: durationMinutes)
        let period = RoutineCalendar.periodText(from: startDate, to: endDate, calendar: calendar)
        return "\(days)  \(time)  \(period)"
    }
}

/// 曜日の並び（月曜始まり）と、ルーティン一覧向けの短い表示。
nonisolated enum RoutineCalendar {
    /// 月・火・水・木・金・土・日
    static let orderedWeekdays = [2, 3, 4, 5, 6, 7, 1]

    static func symbol(for weekday: Int, calendar: Calendar = .current) -> String {
        let symbols = calendar.veryShortWeekdaySymbols
        let index = (weekday - 1) % 7
        guard symbols.indices.contains(index) else { return "" }
        return symbols[index]
    }

    static func summary(for weekdays: Set<Int>, calendar: Calendar = .current) -> String {
        if weekdays.count == 7 { return "毎日" }
        let labels = orderedWeekdays
            .filter { weekdays.contains($0) }
            .map { symbol(for: $0, calendar: calendar) }
        return labels.joined(separator: "・")
    }

    static func periodText(from start: Date, to end: Date, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d"
        return "\(formatter.string(from: start))–\(formatter.string(from: end))"
    }
}
