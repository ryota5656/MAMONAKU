import SwiftUI

/// カレンダーヘッダーの上段。左に曜日、右に日付（タップで日付選択を開く）。
struct CalendarHeaderTopBar: View {
    @Environment(\.appTheme) private var theme
    let selectedDate: Date
    let onTapDate: () -> Void

    var body: some View {
        HStack {
            CalendarHeaderWeekdayLabel(date: selectedDate)

            Spacer()

            Button(action: onTapDate) {
                Text(CalendarHeaderDateFormatting.dateText(for: selectedDate))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(theme.textSecondary)
                    .multilineTextAlignment(.trailing)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.top, 10)
    }
}

#Preview("TopBar") {
    CalendarHeaderTopBar(selectedDate: Date(), onTapDate: {})
        .background(Color(.systemBackground))
}
