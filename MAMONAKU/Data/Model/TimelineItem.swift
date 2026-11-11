import Foundation

/// タイムライン上の予定、または未配置（Stock）のタスク。
///
/// - `dropDate == nil`: Stock にあるタスク
/// - `dropDate != nil` かつ `startMinutes != nil`: タイムラインに配置済みの予定
/// - `isAllDay`: 終日予定（標準カレンダーからの取り込みで発生）
nonisolated struct TimelineItem: Identifiable, Equatable, Codable, Sendable {
    let id: UUID
    var title: String
    var durationMinutes: Int
    /// 配置日の 0 時からの経過分。
    var startMinutes: Int?
    /// 配置日（その日の 0 時）。
    var dropDate: Date?
    var isCompleted: Bool
    var priority: TaskPriority
    var isAllDay: Bool
    /// 将来的なタスク個別バッファ分（現状は全体設定が優先）
    var bufferMinutes: Int?

    init(
        id: UUID = UUID(),
        title: String,
        durationMinutes: Int,
        startMinutes: Int? = nil,
        dropDate: Date? = nil,
        isCompleted: Bool = false,
        priority: TaskPriority = .medium,
        isAllDay: Bool = false,
        bufferMinutes: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.durationMinutes = durationMinutes
        self.startMinutes = startMinutes
        self.dropDate = dropDate
        self.isCompleted = isCompleted
        self.priority = priority
        self.isAllDay = isAllDay
        self.bufferMinutes = bufferMinutes
    }
}

nonisolated extension TimelineItem {
    /// Stock（未配置）のタスクか。
    var isInStock: Bool { dropDate == nil }

    /// 指定日に配置されているか。
    func isPlaced(on date: Date, calendar: Calendar = .current) -> Bool {
        guard let dropDate else { return false }
        return calendar.isDate(dropDate, inSameDayAs: date)
    }

    /// 開始日時。未配置または終日などで開始分が無い場合は nil。
    func startDate(calendar: Calendar = .current) -> Date? {
        guard let dropDate, let startMinutes else { return nil }
        return calendar.date(byAdding: .minute, value: startMinutes, to: calendar.startOfDay(for: dropDate))
    }
}

nonisolated extension Array where Element == TimelineItem {
    /// `date` と同じ日の予定のうち、`date` より後に開始する最初のもの。
    /// 残り 1 分でも「次」として扱えるよう秒単位で比較する。
    func nextItem(after date: Date, calendar: Calendar = .current) -> TimelineItem? {
        let nowSeconds = DayTime.secondsSinceMidnight(of: date, calendar: calendar)
        return self
            .filter { $0.startMinutes != nil && $0.isPlaced(on: date, calendar: calendar) }
            .filter { ($0.startMinutes ?? 0) * 60 > nowSeconds }
            .min { ($0.startMinutes ?? 0) < ($1.startMinutes ?? 0) }
    }
}

nonisolated enum TaskPriority: Int, CaseIterable, Codable, Equatable, Sendable {
    case low = 0
    case medium = 1
    case high = 2

    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }

    var iconName: String {
        switch self {
        case .low: return "minus"
        case .medium: return "chevron.up"
        case .high: return "chevron.up.2"
        }
    }
}
