import SwiftUI

/// 日付ストリップの 1 日分（日と曜日）。
struct CalendarWeekDayCell: View {
    @Environment(\.appTheme) private var theme
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let onTap: () -> Void

    var body: some View {
        let textColor: Color = isToday ? theme.strongAccent : (isSelected ? .primary : theme.textSecondary)

        Button(action: onTap) {
            VStack(spacing: 4) {
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(textColor)
                    .frame(width: 24)
                Text(CalendarHeaderDateFormatting.shortWeekdaySymbol(for: date))
                    .font(.system(size: 6, weight: .semibold))
                    .foregroundColor(textColor)
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
}
