import SwiftUI

struct CountdownHeaderView: View {
    let items: [TimelineItem]
    @Binding var isExpanded: Bool

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let nowSeconds = secondsSinceMidnight(date: context.date)
            let next = nextItem(afterSeconds: nowSeconds)
            let targetSeconds = (next?.startMinutes ?? 0) * 60
            let diff = max(0, targetSeconds - nowSeconds)

            VStack {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 0) {
                            Text(next != nil ? "Next event in..." : "Today's Status")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.black.opacity(0.6))
                                .padding(.bottom, -5)

                            if let _ = next {
                                CountdownDisplay(seconds: diff)
                                    .padding(.bottom, -5)
                            } else {
                                Text("NO PLAN")
                                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                                    .foregroundColor(.black.opacity(0.8))
                                    .padding(.bottom, -5)
                                    .rotationEffect(.degrees(-2))
                            }
                    }
                    nextInfoCard(next: next)
                }
                .padding(.bottom, 5)
                    
                    
                VStack {
                    if let _ = next, diff <= 3600 {
                        CountdownProgressBar(secondsRemaining: diff)
                        HStack {
                            TypewriterText(text: next != nil ? ">>> Next event in..." : ">>> Have a nice day!", interval: 0.05)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.black.opacity(0.6))
                                .padding(.bottom, -5)
                                .padding(.leading, 5)
                            Spacer()
                        }
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

    @ViewBuilder
    private func nextInfoCard(next: TimelineItem?) -> some View {
        if let next {
            VStack(alignment: .leading, spacing: 6) {
                Text(minutesToTime(next.startMinutes ?? 0))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.black.opacity(0.8))
                Text(next.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.black.opacity(0.6))
                    .lineLimit(2)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.black.opacity(0.05))
            )
        }
    }
}

private struct CountdownDisplay: View {
    let seconds: Int

    var body: some View {
        let parts = components
        HStack(spacing: 5) {
            CountdownDigit(text: parts.h)
            CountdownSeparator()
            CountdownDigit(text: parts.m)
            CountdownSeparator()
            CountdownDigit(text: parts.s)
        }
        .frame(width: 170, alignment: .leading)
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
            .font(.system(size: 30,weight: .heavy, design: .rounded))
//            .font(.custom("kohinoorGujarati-Bold", size: 36))
            .foregroundColor(Color.black.opacity(0.9))
            .monospacedDigit()
            .contentTransition(.numericText())
    }
}

private struct CountdownSeparator: View {
    var body: some View {
        Text(":")
            .font(.system(size: 30,weight: .heavy, design: .rounded))
            .foregroundColor(Color.black)
    }
}

private struct CountdownProgressBar: View {
    let secondsRemaining: Int

    private var clampedSeconds: Int {
        max(0, min(3600, secondsRemaining))
    }

    private var progress: CGFloat {
        1.0 - (CGFloat(clampedSeconds) / 3600.0)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { proxy in
                let width = proxy.size.width
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.black.opacity(0.06))
                    Capsule()
                        .fill(Color.black)
                        .frame(width: max(6, width * progress))
                    HStack(spacing: 0) {
                        ForEach(0..<5, id: \.self) { index in
                            Circle()
                                .fill(Color.black)
                                .frame(width: 6, height: 6)
                                .opacity(0.15)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
            .frame(height: 20)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TypewriterText: View {
    let text: String
    let interval: TimeInterval
    @State private var visibleCount = 0
    @State private var animationTask: Task<Void, Never>?

    var body: some View {
        Text(String(text.prefix(visibleCount)))
            .onAppear {
                startAnimation()
            }
            .onChange(of: text) { _, _ in
                startAnimation()
            }
            .onDisappear {
                animationTask?.cancel()
                animationTask = nil
            }
    }

    private func startAnimation() {
        animationTask?.cancel()
        visibleCount = 0
        animationTask = Task {
            let characters = Array(text)
            for index in 0...characters.count {
                if Task.isCancelled { return }
                await MainActor.run {
                    visibleCount = index
                }
                let sleepNanos = UInt64(interval * 1_000_000_000)
                try? await Task.sleep(nanoseconds: sleepNanos)
            }
        }
    }
}

#Preview{
    ContentView()
}

#Preview("timeline with items") {
    TimelineScreen(items: [
        TimelineItem(title: "Wake up", durationMinutes: 15, startMinutes: 21 * 60, dropDate: Date()),
        TimelineItem(title: "Workout", durationMinutes: 60, startMinutes: 2 * 60 + 45, dropDate: Date()),
        TimelineItem(title: "Breakfast", durationMinutes: 30, startMinutes: 4 * 60, dropDate: Date()),
        TimelineItem(title: "Study", durationMinutes: 120, startMinutes: 5 * 60, dropDate: Date())
    ])
}
