import Foundation

enum CalendarHeaderDateFormatting {
    static func dateText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d\nyyyy"
        return formatter.string(from: date)
    }

    static func weekDates(for date: Date) -> [Date] {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: date)
        let startOffset = (weekday + 5) % 7 // Monday start
        let start = cal.date(byAdding: .day, value: -startOffset, to: date) ?? date
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    static func addDays(_ value: Int, to date: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: value, to: date) ?? date
    }

    static func shortWeekdaySymbol(for date: Date) -> String {
        let cal = Calendar.current
        let index = (cal.component(.weekday, from: date) - 1) % 7
        let symbol = cal.weekdaySymbols[index]
        return String(symbol.prefix(3)).uppercased()
    }

    static func weekdaySymbol(for date: Date) -> String {
        let cal = Calendar.current
        return cal.weekdaySymbols[(cal.component(.weekday, from: date) - 1) % 7]
    }
}
