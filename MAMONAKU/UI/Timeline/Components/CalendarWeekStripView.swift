import SwiftUI

/// 日付を横スクロールで辿れるストリップ（シェブロンなし）。
struct CalendarWeekStripView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @Binding var selectedDate: Date
    @Binding var isTwoDayView: Bool

    @State private var rangeCenter: Date = Calendar.current.startOfDay(for: Date())
    private let dayCellWidth: CGFloat = 48
    /// 旧週ストリップと同程度の高さ（横 ScrollView が縦に伸びないよう固定）
    private let dayStripHeight: CGFloat = 48
    private let dayRangeRadius = 180

    var body: some View {
        let cal = Calendar.current
        let dates = dayDates(center: rangeCenter)

        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 0) {
                    ForEach(dates, id: \.self) { date in
                        let day = cal.startOfDay(for: date)
                        CalendarWeekDayCell(
                            date: day,
                            isSelected: cal.isDate(day, inSameDayAs: selectedDate),
                            isToday: cal.isDateInToday(day)
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                if cal.isDate(day, inSameDayAs: selectedDate) {
                                    isTwoDayView.toggle()
                                } else {
                                    selectedDate = day
                                    isTwoDayView = false
                                }
                            }
                        }
                        .frame(width: dayCellWidth, height: dayStripHeight)
                        .id(day)
                    }
                }
            }
            .frame(height: dayStripHeight)
            .onAppear {
                syncRangeCenterIfNeeded(for: selectedDate)
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 50_000_000)
                    scrollToSelected(proxy: proxy, animated: false)
                }
            }
            .onChange(of: selectedDate) { _, newDate in
                syncRangeCenterIfNeeded(for: newDate)
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 30_000_000)
                    scrollToSelected(proxy: proxy, animated: true)
                }
            }
        }
    }

    private func dayDates(center: Date) -> [Date] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: center)
        return (-dayRangeRadius...dayRangeRadius).compactMap {
            cal.date(byAdding: .day, value: $0, to: start)
        }
    }

    private func syncRangeCenterIfNeeded(for date: Date) {
        let cal = Calendar.current
        let day = cal.startOfDay(for: date)
        let offset = cal.dateComponents([.day], from: rangeCenter, to: day).day ?? 0
        if abs(offset) > dayRangeRadius - 30 {
            rangeCenter = day
        }
    }

    private func scrollToSelected(proxy: ScrollViewProxy, animated: Bool) {
        let day = Calendar.current.startOfDay(for: selectedDate)
        let action = {
            proxy.scrollTo(day, anchor: .center)
        }
        if animated {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85), action)
        } else {
            action()
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
