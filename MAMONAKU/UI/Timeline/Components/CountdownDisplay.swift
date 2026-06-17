import SwiftUI

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
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 30, weight: .heavy, design: .rounded))
            .foregroundColor(AppColors.textPrimary(palette: themeManager.theme, environmentScheme: colorScheme))
            .monospacedDigit()
            .contentTransition(.numericText())
    }
}

private struct CountdownSeparator: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        Text(":")
            .font(.system(size: 30, weight: .heavy, design: .rounded))
            .foregroundColor(AppColors.textPrimary(palette: themeManager.theme, environmentScheme: colorScheme))
    }
}

#Preview("CountdownDisplay") {
    CountdownDisplay(seconds: 1 * 3600 + 23 * 60 + 45)
        .padding()
        .environmentObject(ThemeManager())
}

