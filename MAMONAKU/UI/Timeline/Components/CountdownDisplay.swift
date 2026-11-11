import SwiftUI

/// 次の予定までの残り時間（HH:MM:SS）。
struct CountdownDisplay: View {
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
    @Environment(\.appTheme) private var theme
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 30, weight: .heavy, design: .rounded))
            .foregroundColor(theme.textPrimary)
            .monospacedDigit()
            .contentTransition(.numericText())
    }
}

private struct CountdownSeparator: View {
    @Environment(\.appTheme) private var theme

    var body: some View {
        Text(":")
            .font(.system(size: 30, weight: .heavy, design: .rounded))
            .foregroundColor(theme.textPrimary)
    }
}

#Preview("CountdownDisplay") {
    CountdownDisplay(seconds: 1 * 3600 + 23 * 60 + 45)
        .padding()
}

