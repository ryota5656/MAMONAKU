import SwiftUI

struct CalendarHeaderWeekdayLabel: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    let date: Date

    var body: some View {
        HStack(spacing: 6) {
            Text(CalendarHeaderDateFormatting.weekdaySymbol(for: date).prefix(3).uppercased())
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.textPrimary(palette: themeManager.theme, environmentScheme: colorScheme))
            Circle()
                .fill(AppColors.strongAccent(palette: themeManager.theme, environmentScheme: colorScheme))
                .frame(width: 8, height: 8)
                .offset(y: -4)
        }
    }
}

#Preview("WeekdayLabel") {
    CalendarHeaderWeekdayLabel(date: Date())
        .padding()
        .background(Color(.systemBackground))
        .environmentObject(ThemeManager())
}

#Preview("WeekdayLabel - Dark") {
    CalendarHeaderWeekdayLabel(date: Date())
        .padding()
        .background(Color(.systemBackground))
        .preferredColorScheme(.dark)
        .environmentObject(ThemeManager())
}
