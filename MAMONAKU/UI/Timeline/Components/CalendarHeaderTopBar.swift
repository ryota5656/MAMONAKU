import SwiftUI

struct CalendarHeaderTopBar: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    let selectedDate: Date
    var isSettingsHighlighted: Bool = false
    var onOpenSettings: () -> Void = {}
    var onOpenMonthCalendar: () -> Void = {}

    var body: some View {
        let secondary = AppColors.textSecondary(palette: themeManager.theme, environmentScheme: colorScheme)

        HStack {
            CalendarHeaderWeekdayLabel(date: selectedDate)
            Spacer()
            CalendarHeaderSettingsButton(
                isHighlighted: isSettingsHighlighted,
                onTap: onOpenSettings
            )
            Button(action: onOpenMonthCalendar) {
                Text(CalendarHeaderDateFormatting.dateText(for: selectedDate))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(secondary)
                    .multilineTextAlignment(.trailing)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.top, 10)
    }
}

#Preview("TopBar") {
    CalendarHeaderTopBar(
        selectedDate: Date(),
        isSettingsHighlighted: false
    )
    .background(Color(.systemBackground))
    .environmentObject(ThemeManager())
}

#Preview("TopBar - Settings Highlighted") {
    CalendarHeaderTopBar(
        selectedDate: Date(),
        isSettingsHighlighted: true
    )
    .background(Color(.systemBackground))
    .environmentObject(ThemeManager())
}
