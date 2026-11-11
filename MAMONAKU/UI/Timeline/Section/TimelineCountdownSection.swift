import SwiftUI

/// 画面最上部の、今日の次の予定までのカウントダウン。1 秒ごとに更新する。
struct TimelineCountdownSection: View {
    @Environment(\.appTheme) private var theme
    let items: [TimelineItem]

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let next = items.nextItem(after: context.date)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 0) {
                    TypewriterText(text: next != nil ? ">>> Next event in..." : ">>> Have a nice day!", interval: 0.05)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(theme.textSecondary)
                        .padding(.bottom, -5)

                    if let next {
                        CountdownDisplay(seconds: secondsUntilStart(of: next, from: context.date))
                            .padding(.bottom, -5)
                    } else {
                        Text("NO PLAN")
                            .font(.system(size: 36, weight: .heavy, design: .rounded))
                            .foregroundColor(theme.textPrimary)
                            .padding(.bottom, -5)
                    }
                }
                CountdownNextInfoCard(next: next)
            }
            .padding(.bottom, 5)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.vertical, 10)
            .padding(.horizontal, 18)
        }
    }

    private func secondsUntilStart(of item: TimelineItem, from date: Date) -> Int {
        max(0, (item.startMinutes ?? 0) * 60 - DayTime.secondsSinceMidnight(of: date))
    }
}

#Preview("予定あり") {
    TimelineCountdownSection(items: [
        TimelineItem(title: "Wake up", durationMinutes: 15, startMinutes: 23 * 60 + 59, dropDate: Date()),
        TimelineItem(title: "Workout", durationMinutes: 60, startMinutes: 2 * 60 + 45, dropDate: Date())
    ])
}

#Preview("予定なし") {
    TimelineCountdownSection(items: [])
}
