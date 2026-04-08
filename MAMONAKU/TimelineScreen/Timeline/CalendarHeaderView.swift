import SwiftUI

struct CalendarHeaderView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @Binding var selectedDate: Date
    @Binding var isTwoDayView: Bool

    var body: some View {
        let cal = Calendar.current
        let weekdaySymbol = cal.weekdaySymbols[(cal.component(.weekday, from: selectedDate) - 1) % 7]
        let dateText = dateText(for: selectedDate)
        let weekDates = weekDates(for: selectedDate)
        let secondary = AppColors.textSecondary(palette: themeManager.theme, environmentScheme: colorScheme)

        VStack(spacing: 8) {
            HStack() {
                HStack(spacing: 6) {
                    Text(weekdaySymbol.prefix(3).uppercased())
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.textPrimary(palette: themeManager.theme, environmentScheme: colorScheme))
                    Circle()
                        .fill(AppColors.strongAccent(palette: themeManager.theme, environmentScheme: colorScheme))
                        .frame(width: 8, height: 8)
                        .offset(y: -4)
                }
                Spacer()
                Text(dateText)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(secondary)
                    .multilineTextAlignment(.trailing)
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)

            HStack(spacing: 0) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        selectedDate = addDays(-7, to: selectedDate)
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
                    let isSelected = cal.isDate(date, inSameDayAs: selectedDate)
                    let isToday = cal.isDateInToday(date)
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            if cal.isDate(date, inSameDayAs: selectedDate) {
                                isTwoDayView.toggle()
                            } else {
                                selectedDate = date
                                isTwoDayView = false
                            }
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Text("\(cal.component(.day, from: date))")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(isToday ? AppColors.strongAccent(palette: themeManager.theme, environmentScheme: colorScheme) : (isSelected ? .primary : secondary))
                                .frame(width: 24)
                            Text(shortWeekdaySymbol(for: date))
                                .font(.system(size: 6, weight: .semibold))
                                .foregroundColor(isToday ? AppColors.strongAccent(palette: themeManager.theme, environmentScheme: colorScheme) : (isSelected ? .primary : secondary))
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

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        selectedDate = addDays(7, to: selectedDate)
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

    private func dateText(for date: Date) -> String {
        let formatter = DateFormatter()
//        formatter.dateFormat = "MMMMd yyyy"
        formatter.dateFormat = "MMMM d\nyyyy"
        return formatter.string(from: date)
    }

    private func weekDates(for date: Date) -> [Date] {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: date)
        let startOffset = (weekday + 5) % 7 // Monday start
        let start = cal.date(byAdding: .day, value: -startOffset, to: date) ?? date
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    private func addDays(_ value: Int, to date: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: value, to: date) ?? date
    }

    private func shortWeekdaySymbol(for date: Date) -> String {
        let cal = Calendar.current
        let index = (cal.component(.weekday, from: date) - 1) % 7
        let symbol = cal.weekdaySymbols[index]
        return String(symbol.prefix(3)).uppercased()
    }
}

#Preview("CalendarHeader") {
    @Previewable @State var selectedDate = Date()
    @Previewable @State var isTwoDayView = false
    CalendarHeaderView(selectedDate: $selectedDate, isTwoDayView: $isTwoDayView)
        .padding()
        .background(Color(.systemBackground))
        .environmentObject(ThemeManager())
}

#Preview{
    ContentView()
        .environmentObject(ThemeManager())
}
