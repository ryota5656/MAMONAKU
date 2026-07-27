import SwiftUI

struct CalendarWeekDayCell: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let onTap: () -> Void

    var body: some View {
        let secondary = AppColors.textSecondary(palette: themeManager.theme, environmentScheme: colorScheme)
        let strongAccent = AppColors.strongAccent(palette: themeManager.theme, environmentScheme: colorScheme)
        let cal = Calendar.current
        let dayColor: Color = isToday ? strongAccent : (isSelected ? .primary : secondary)
        let weekdayColor: Color = isToday ? strongAccent : (isSelected ? .primary : secondary)

        Button(action: onTap) {
            VStack(spacing: 4) {
                Text("\(cal.component(.day, from: date))")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(dayColor)
                    .frame(width: 24)
                Text(CalendarHeaderDateFormatting.shortWeekdaySymbol(for: date))
                    .font(.system(size: 6, weight: .semibold))
                    .foregroundColor(weekdayColor)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(isSelected ? Color.secondary.opacity(0.4) : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview("WeekDayCell - Today") {
    CalendarWeekDayCell(
        date: Date(),
        isSelected: true,
        isToday: true,
        onTap: {}
    )
    .padding()
    .background(Color(.systemBackground))
    .environmentObject(ThemeManager())
}

#Preview("WeekDayCell - Selected") {
    let date = Calendar.current.date(byAdding: .day, value: 2, to: Date()) ?? Date()
    CalendarWeekDayCell(
        date: date,
        isSelected: true,
        isToday: false,
        onTap: {}
    )
    .padding()
    .background(Color(.systemBackground))
    .environmentObject(ThemeManager())
}

#Preview("WeekDayCell - Normal") {
    let date = Calendar.current.date(byAdding: .day, value: 4, to: Date()) ?? Date()
    CalendarWeekDayCell(
        date: date,
        isSelected: false,
        isToday: false,
        onTap: {}
    )
    .padding()
    .background(Color(.systemBackground))
    .environmentObject(ThemeManager())
}
