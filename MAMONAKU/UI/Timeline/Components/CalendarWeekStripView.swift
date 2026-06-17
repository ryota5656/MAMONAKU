import SwiftUI

struct CalendarWeekStripView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @Binding var selectedDate: Date
    @Binding var isTwoDayView: Bool

    var body: some View {
        let cal = Calendar.current
        let weekDates = CalendarHeaderDateFormatting.weekDates(for: selectedDate)
        let secondary = AppColors.textSecondary(palette: themeManager.theme, environmentScheme: colorScheme)

        HStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    selectedDate = CalendarHeaderDateFormatting.addDays(-7, to: selectedDate)
                    isTwoDayView = false
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(secondary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)

            ForEach(weekDates, id: \.self) { date in
                CalendarWeekDayCell(
                    date: date,
                    isSelected: cal.isDate(date, inSameDayAs: selectedDate),
                    isToday: cal.isDateInToday(date)
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        if cal.isDate(date, inSameDayAs: selectedDate) {
                            isTwoDayView.toggle()
                        } else {
                            selectedDate = date
                            isTwoDayView = false
                        }
                    }
                }
            }

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    selectedDate = CalendarHeaderDateFormatting.addDays(7, to: selectedDate)
                    isTwoDayView = false
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(secondary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview("WeekStrip") {
    @Previewable @State var selectedDate = Date()
    @Previewable @State var isTwoDayView = false
    CalendarWeekStripView(
        selectedDate: $selectedDate,
        isTwoDayView: $isTwoDayView
    )
    .padding()
    .background(Color(.systemBackground))
    .environmentObject(ThemeManager())
}

#Preview("WeekStrip - TwoDay") {
    @Previewable @State var selectedDate = Date()
    @Previewable @State var isTwoDayView = true
    CalendarWeekStripView(
        selectedDate: $selectedDate,
        isTwoDayView: $isTwoDayView
    )
    .padding()
    .background(Color(.systemBackground))
    .environmentObject(ThemeManager())
}
