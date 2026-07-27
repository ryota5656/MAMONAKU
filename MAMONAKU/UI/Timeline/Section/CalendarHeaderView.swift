import SwiftUI

struct CalendarHeaderView: View {
    @Binding var selectedDate: Date
    @Binding var isTwoDayView: Bool
    var isSettingsHighlighted: Bool = false
    var onOpenSettings: () -> Void = {}
    @State private var isMonthCalendarPresented: Bool = false

    var body: some View {
        VStack(spacing: 8) {
            CalendarHeaderTopBar(
                selectedDate: selectedDate,
                isSettingsHighlighted: isSettingsHighlighted,
                onOpenSettings: onOpenSettings,
                onOpenMonthCalendar: { isMonthCalendarPresented = true }
            )

            CalendarWeekStripView(
                selectedDate: $selectedDate,
                isTwoDayView: $isTwoDayView
            )
        }
        .sheet(isPresented: $isMonthCalendarPresented) {
            CalendarMonthPickerSheet(
                selectedDate: $selectedDate,
                isTwoDayView: $isTwoDayView,
                isPresented: $isMonthCalendarPresented
            )
        }
    }
}

#Preview("CalendarHeader") {
    @Previewable @State var selectedDate = Date()
    @Previewable @State var isTwoDayView = false
    CalendarHeaderView(
        selectedDate: $selectedDate,
        isTwoDayView: $isTwoDayView
    )
    .padding()
    .background(Color(.systemBackground))
    .environmentObject(ThemeManager())
}

#Preview("CalendarHeader - Settings Highlighted") {
    @Previewable @State var selectedDate = Date()
    @Previewable @State var isTwoDayView = false
    CalendarHeaderView(
        selectedDate: $selectedDate,
        isTwoDayView: $isTwoDayView,
        isSettingsHighlighted: true
    )
    .padding()
    .background(Color(.systemBackground))
    .environmentObject(ThemeManager())
}

#Preview("CalendarHeader - TwoDay View") {
    @Previewable @State var selectedDate = Date()
    @Previewable @State var isTwoDayView = true
    CalendarHeaderView(
        selectedDate: $selectedDate,
        isTwoDayView: $isTwoDayView
    )
    .padding()
    .background(Color(.systemBackground))
    .environmentObject(ThemeManager())
}

#Preview("CalendarHeader - Dark") {
    @Previewable @State var selectedDate = Date()
    @Previewable @State var isTwoDayView = false
    CalendarHeaderView(
        selectedDate: $selectedDate,
        isTwoDayView: $isTwoDayView,
        isSettingsHighlighted: true
    )
    .padding()
    .background(Color(.systemBackground))
    .preferredColorScheme(.dark)
    .environmentObject(ThemeManager())
}
