import SwiftUI

/// 選択中の日の曜日（3 文字）。
struct CalendarHeaderWeekdayLabel: View {
    @Environment(\.appTheme) private var theme
    let date: Date

    var body: some View {
        HStack(spacing: 6) {
            Text(CalendarHeaderDateFormatting.weekdaySymbol(for: date).prefix(3).uppercased())
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(theme.textPrimary)
            Circle()
                .fill(theme.strongAccent)
                .frame(width: 8, height: 8)
                .offset(y: -4)
        }
    }
}

#Preview("WeekdayLabel") {
    CalendarHeaderWeekdayLabel(date: Date())
        .padding()
        .background(Color(.systemBackground))
}

#Preview("WeekdayLabel - Dark") {
    CalendarHeaderWeekdayLabel(date: Date())
        .padding()
        .background(Color(.systemBackground))
        .environment(\.appTheme, .dark)
        .preferredColorScheme(.dark)
}
