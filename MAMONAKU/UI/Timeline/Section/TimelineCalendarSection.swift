import SwiftUI

/// タイムラインシート上部の日付ヘッダー（曜日・日付・日付ストリップ）。
struct TimelineCalendarSection: View {
    let selectedDate: Date
    let onSelectDate: (Date) -> Void
    let onTapDateLabel: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            CalendarHeaderTopBar(selectedDate: selectedDate, onTapDate: onTapDateLabel)
            CalendarWeekStripView(selectedDate: selectedDate, onSelectDate: onSelectDate)
        }
    }
}

#Preview("TimelineCalendarSection") {
    @Previewable @State var selectedDate = Date()
    TimelineCalendarSection(
        selectedDate: selectedDate,
        onSelectDate: { selectedDate = $0 },
        onTapDateLabel: {}
    )
    .padding()
    .background(Color(.systemBackground))
}
