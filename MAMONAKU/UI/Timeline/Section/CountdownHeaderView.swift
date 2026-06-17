import SwiftUI

struct CountdownHeaderView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    let items: [TimelineItem]

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let nowSeconds = secondsSinceMidnight(date: context.date)
            let next = nextItem(afterSeconds: nowSeconds)
            let targetSeconds = (next?.startMinutes ?? 0) * 60
            let diff = max(0, targetSeconds - nowSeconds)

            VStack {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 0) {
                            TypewriterText(text: next != nil ? ">>> Next event in..." : ">>> Have a nice day!", interval: 0.05)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(AppColors.textSecondary(palette: themeManager.theme, environmentScheme: colorScheme))
                                .padding(.bottom, -5)

                            if let _ = next {
                                CountdownDisplay(seconds: diff)
                                    .padding(.bottom, -5)
                            } else {
                                Text("NO PLAN")
                                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                                    .foregroundColor(AppColors.textPrimary(palette: themeManager.theme, environmentScheme: colorScheme))
                                    .padding(.bottom, -5)
                            }
                    }
                    CountdownNextInfoCard(next: next)
                }
                .padding(.bottom, 5)
                    
                    
                VStack {
                    if let _ = next, diff <= 3600 {
                        TimelineCountdownProgressBar(
                            secondsRemaining: diff,
                            accent: AppColors.textPrimary(palette: themeManager.theme, environmentScheme: colorScheme)
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.top, 20)
            .padding(.bottom, 20)
            .padding(.horizontal, 18)
        }

    }

    private func secondsSinceMidnight(date: Date) -> Int {
        let cal = Calendar.current
        let comps = cal.dateComponents([.hour, .minute, .second], from: date)
        let h = comps.hour ?? 0
        let m = comps.minute ?? 0
        let s = comps.second ?? 0
        return (h * 3600) + (m * 60) + s
    }

    /// 指定秒数（0時からの経過秒）より後に開始する、今日の最初の予定を返す。残り1分のときも「次」として表示するため秒単位で比較する。
    private func nextItem(afterSeconds seconds: Int) -> TimelineItem? {
        let todayItems = items.filter { item in
            guard let dropDate = item.dropDate else { return false }
            return Calendar.current.isDateInToday(dropDate)
        }
        let candidates: [(TimelineItem, Int)] = todayItems.compactMap { item in
            guard let minutes = item.startMinutes else { return nil }
            return (item, minutes * 60)
        }
        return candidates
            .filter { $0.1 > seconds }
            .min(by: { $0.1 < $1.1 })?
            .0
    }

}

#Preview("timeline with items") {
    CountdownHeaderView(items: [
        TimelineItem(title: "Wake up", durationMinutes: 15, startMinutes: 21 * 60, dropDate: Date()),
        TimelineItem(title: "Workout", durationMinutes: 60, startMinutes: 2 * 60 + 45, dropDate: Date()),
        TimelineItem(title: "Breakfast", durationMinutes: 30, startMinutes: 4 * 60, dropDate: Date()),
        TimelineItem(title: "Study", durationMinutes: 120, startMinutes: 5 * 60, dropDate: Date())
    ])
    .environmentObject(SubscriptionManager())
    .environmentObject(ThemeManager())
}

#Preview("timeline no plan") {
    CountdownHeaderView(items: [])
        .environmentObject(SubscriptionManager())
        .environmentObject(ThemeManager())
}
