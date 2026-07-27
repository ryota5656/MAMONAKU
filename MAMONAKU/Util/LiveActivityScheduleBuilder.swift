import Foundation

/// 今日の予定から Live Activity 用スロットとローテーション予約を組み立てる。
/// - free: 表示は常に最大1件。1件開始後は次の1件へローテーション（後続の同時スタック表示はしない）
/// - plus: 表示は最大3件スタック
enum LiveActivityScheduleBuilder {
    /// 無料: 1件ずつ表示（同時スタックなし）。PLUS: 最大3件スタック表示。
    enum PlanScope {
        case free
        case plus

        var maxVisibleSlots: Int {
            switch self {
            case .free: return 1
            case .plus: return 3
            }
        }
    }

    struct ScheduledEntry {
        let item: TimelineItem
        let startDate: Date
        let endDate: Date
    }

    struct Rotation {
        let switchAt: Date
        let schedule: [ActivityTaskItem]
        let shouldEndActivity: Bool
        let reason: String
    }

    static func entriesForToday(
        items: [TimelineItem],
        referenceDate: Date = Date(),
        planScope: PlanScope = .plus
    ) -> [ScheduledEntry] {
        let calendar = Calendar.current
        // プランに依らず当日の全配置予定を返す。
        // 無料も「次の1件」へローテーションするためエントリは全日分を保持し、
        // 同時表示件数の制限だけ currentWindow / maxVisibleSlots で行う。
        _ = planScope
        return items
            .filter { item in
                guard !item.isAllDay,
                      let dropDate = item.dropDate,
                      item.startMinutes != nil
                else { return false }
                return calendar.isDateInToday(dropDate)
            }
            .sorted { ($0.startMinutes ?? 0) < ($1.startMinutes ?? 0) }
            .compactMap { item -> ScheduledEntry? in
                guard let startMinutes = item.startMinutes else { return nil }
                let startOfDay = calendar.startOfDay(for: referenceDate)
                guard let startDate = calendar.date(byAdding: .minute, value: startMinutes, to: startOfDay) else {
                    return nil
                }
                let endDate = startDate.addingTimeInterval(TimeInterval(item.durationMinutes * 60))
                return ScheduledEntry(item: item, startDate: startDate, endDate: endDate)
            }
    }

    /// まだ開始していない最初の予定から、プランに応じた件数のウィンドウを返す。
    static func currentWindow(
        entries: [ScheduledEntry],
        now: Date = Date(),
        planScope: PlanScope = .plus
    ) -> (startIndex: Int, window: ArraySlice<ScheduledEntry>) {
        guard !entries.isEmpty else { return (0, entries[0..<0]) }

        let currentIndex = entries.firstIndex { entry in
            entry.startDate > now
        } ?? entries.count

        guard currentIndex < entries.count else {
            return (entries.count, entries[entries.count..<entries.count])
        }

        let endIndex = min(currentIndex + planScope.maxVisibleSlots, entries.count)
        return (currentIndex, entries[currentIndex..<endIndex])
    }

    static func buildTaskItems(
        from window: ArraySlice<ScheduledEntry>,
        now: Date = Date(),
        bufferMinutes: (TimelineItem) -> Int?
    ) -> [ActivityTaskItem] {
        window.enumerated().map { index, entry in
            let buffer = bufferMinutes(entry.item)
            if index == 0 {
                return ActivityTaskItem(
                    nextTitle: entry.item.title,
                    nextStartDate: entry.startDate,
                    nextEndDate: entry.endDate,
                    countdownStartDate: now,
                    remainingTimeShort: shortCountdown(to: entry.startDate, from: now),
                    bufferMinutes: buffer
                )
            }
            return ActivityTaskItem(
                nextTitle: entry.item.title,
                nextStartDate: entry.startDate,
                nextEndDate: nil,
                countdownStartDate: nil,
                remainingTimeShort: stackTimeLabel(startDate: entry.startDate, now: now),
                bufferMinutes: buffer
            )
        }
    }

    /// 各予定の開始時刻にスタックをローテーションする。
    /// プライマリのカウントダウンが 0:00 になった瞬間、次の予定のカウントダウンを開始する。
    static func buildRotations(
        entries: [ScheduledEntry],
        startIndex: Int,
        now: Date = Date(),
        planScope: PlanScope = .plus,
        bufferMinutes: (TimelineItem) -> Int?
    ) -> [Rotation] {
        guard startIndex < entries.count else { return [] }

        var rotations: [Rotation] = []

        for index in startIndex..<entries.count {
            let switchAt = entries[index].startDate
            guard switchAt > now else { continue }

            let isLast = index == entries.count - 1
            if isLast {
                rotations.append(
                    Rotation(
                        switchAt: switchAt,
                        schedule: [],
                        shouldEndActivity: true,
                        reason: planScope == .free ? "free_single_event_started" : "last_event_started"
                    )
                )
                continue
            }

            let nextIndex = index + 1
            // free は常に1件、plus は最大3件。後続を同時表示しないよう slots で厳密に切る。
            let windowEnd = min(nextIndex + planScope.maxVisibleSlots, entries.count)
            let window = entries[nextIndex..<windowEnd]
            let schedule = Array(
                buildTaskItems(from: window, now: switchAt, bufferMinutes: bufferMinutes)
                    .prefix(planScope.maxVisibleSlots)
            )
            rotations.append(
                Rotation(
                    switchAt: switchAt,
                    schedule: schedule,
                    shouldEndActivity: false,
                    reason: planScope == .free ? "free_next_single_event" : "next_event_countdown"
                )
            )
        }

        return rotations
    }

    private static func shortCountdown(to targetDate: Date, from now: Date) -> String {
        let seconds = max(0, Int(targetDate.timeIntervalSince(now)))
        if seconds >= 3600 {
            let hours = seconds / 3600
            let minutes = (seconds % 3600) / 60
            return String(format: "%d:%02d", hours, minutes)
        }
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    private static func stackTimeLabel(startDate: Date, now: Date) -> String {
        let minutes = max(0, Int(startDate.timeIntervalSince(now) / 60))
        if minutes < 120 {
            return "\(minutes)分後"
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: startDate)
    }
}
