import Foundation

/// カレンダーヘッダーに表示する日付・曜日の文字列。
enum CalendarHeaderDateFormatting {
    static func dateText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d\nyyyy"
        return formatter.string(from: date)
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
