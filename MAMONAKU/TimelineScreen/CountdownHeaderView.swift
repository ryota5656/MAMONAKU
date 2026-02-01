import SwiftUI

struct CountdownHeaderView: View {
    let items: [TimelineItem]

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let nowSeconds = secondsSinceMidnight(date: context.date)
            let next = nextItem(afterSeconds: nowSeconds)
            let targetSeconds = (next?.startMinutes ?? 0) * 60
            let diff = max(0, targetSeconds - nowSeconds)

            VStack(alignment: .center, spacing: 10) {
                Text("次の予定まで")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.black.opacity(0.6))

                if let _ = next {
                    CountdownDisplay(seconds: diff)
                } else {
                    Text("予定なし")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.black.opacity(0.6))
                }

                if let next {
                    Text("\(next.title) \(minutesToTime(next.startMinutes ?? 0))")
                        .font(.system(size: 12))
                        .foregroundColor(.black.opacity(0.5))
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
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

    private func nextItem(afterSeconds seconds: Int) -> TimelineItem? {
        let startMinutes = Int(ceil(Double(seconds) / 60.0))
        let todayItems = items.filter { item in
            guard let dropDate = item.dropDate else { return false }
            return Calendar.current.isDateInToday(dropDate)
        }
        let candidates: [(TimelineItem, Int)] = todayItems.compactMap { item in
            guard let minutes = item.startMinutes else { return nil }
            return (item, minutes)
        }
        return candidates
            .filter { $0.1 >= startMinutes }
            .min(by: { $0.1 < $1.1 })?
            .0
    }

    private func minutesToTime(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        return String(format: "%02d:%02d", h, m)
    }
}

private struct CountdownDisplay: View {
    let seconds: Int

    var body: some View {
        let parts = components
        HStack(spacing: 12) {
            CountdownDigit(text: parts.h)
            CountdownSeparator()
            CountdownDigit(text: parts.m)
            CountdownSeparator()
            CountdownDigit(text: parts.s)
        }
        .animation(.easeInOut(duration: 0.2), value: seconds)
    }

    private var components: (h: String, m: String, s: String) {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        return (
            String(format: "%02d", h),
            String(format: "%02d", m),
            String(format: "%02d", s)
        )
    }
}

private struct CountdownDigit: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.custom("DevanagariSangamMN-Bold", size: 44))
            .foregroundColor(Color.black.opacity(0.9))
            .monospacedDigit()
            .contentTransition(.numericText())
    }
}

private struct CountdownSeparator: View {
    var body: some View {
        Text(":")
            .font(.system(size: 34, weight: .light, design: .rounded))
            .foregroundColor(Color.black)
    }
}
