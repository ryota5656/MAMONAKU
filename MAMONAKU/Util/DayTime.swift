import Foundation

/// 「0 時からの経過分 / 秒」で表す 1 日内の時刻の計算と表示。
nonisolated enum DayTime {
    static let minutesPerDay = 24 * 60

    /// 0 時からの経過分。
    static func minutesSinceMidnight(of date: Date, calendar: Calendar = .current) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    /// 0 時からの経過秒。
    static func secondsSinceMidnight(of date: Date, calendar: Calendar = .current) -> Int {
        let components = calendar.dateComponents([.hour, .minute, .second], from: date)
        return (components.hour ?? 0) * 3600 + (components.minute ?? 0) * 60 + (components.second ?? 0)
    }

    /// 経過分を "HH:mm" にする。24 時以降は 0 時に折り返す（1440 → "00:00"）。
    static func clockText(minutes: Int) -> String {
        String(format: "%02d:%02d", (minutes / 60) % 24, minutes % 60)
    }

    /// 開始〜終了の表示（例: "09:00 - 10:30"）。
    static func rangeText(startMinutes: Int, durationMinutes: Int) -> String {
        "\(clockText(minutes: startMinutes)) - \(clockText(minutes: startMinutes + durationMinutes))"
    }
}
