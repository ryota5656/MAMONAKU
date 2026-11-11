import Foundation
@testable import MAMONAKU

/// テストごとに独立した空の UserDefaults を作る（アプリ本体の設定を読み書きしないため）。
func makeIsolatedDefaults() -> UserDefaults {
    let suiteName = "MAMONAKUTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
}

/// テストで使う固定の日時（2026-01-15）。
enum TestTime {
    static let calendar = Calendar.current

    /// 基準日の 0 時
    static let today: Date = calendar.date(from: DateComponents(year: 2026, month: 1, day: 15))!

    static var tomorrow: Date { calendar.date(byAdding: .day, value: 1, to: today)! }

    /// 基準日の指定時刻
    static func date(hour: Int, minute: Int = 0, second: Int = 0) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: second, of: today)!
    }
}

/// テストから進められる現在時刻。
final class TestClock {
    var now: Date

    init(now: Date) {
        self.now = now
    }

    func advance(by seconds: TimeInterval) {
        now = now.addingTimeInterval(seconds)
    }
}

extension TimelineItem {
    /// 基準日のタイムラインに配置済みの予定を作る。
    static func placed(
        _ title: String,
        startMinutes: Int,
        durationMinutes: Int = 30,
        on date: Date = TestTime.today,
        isAllDay: Bool = false
    ) -> TimelineItem {
        TimelineItem(
            title: title,
            durationMinutes: durationMinutes,
            startMinutes: startMinutes,
            dropDate: date,
            isAllDay: isAllDay
        )
    }

    /// Stock のタスクを作る。
    static func stock(_ title: String, durationMinutes: Int = 30) -> TimelineItem {
        TimelineItem(title: title, durationMinutes: durationMinutes)
    }
}

/// 非同期に反映される状態を待つ。`timeout` までに条件を満たせば true。
@MainActor
func eventually(timeout: Duration = .seconds(2), _ condition: @MainActor () -> Bool) async -> Bool {
    let deadline = ContinuousClock.now + timeout
    while !condition() {
        guard ContinuousClock.now < deadline else { return false }
        try? await Task.sleep(for: .milliseconds(10))
    }
    return true
}
