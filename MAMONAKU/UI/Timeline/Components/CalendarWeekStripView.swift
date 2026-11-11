import SwiftUI

/// 日付を横スクロールで辿れるストリップ。選択中の日が中央に来るようスクロールする。
struct CalendarWeekStripView: View {
    let selectedDate: Date
    let onSelectDate: (Date) -> Void

    /// 並べる日付の中心。選択日が端に近づいたときだけ動かす（毎回動かすとスクロール位置が飛ぶため）。
    @State private var rangeCenter: Date = Calendar.current.startOfDay(for: Date())

    private let dayCellWidth: CGFloat = 48
    /// 横 ScrollView が縦に伸びないよう高さを固定する
    private let dayStripHeight: CGFloat = 48
    /// 中心から前後に並べる日数
    private let dayRangeRadius = 180

    var body: some View {
        let calendar = Calendar.current

        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 0) {
                    ForEach(dayDates, id: \.self) { day in
                        CalendarWeekDayCell(
                            date: day,
                            isSelected: calendar.isDate(day, inSameDayAs: selectedDate),
                            isToday: calendar.isDateInToday(day)
                        ) {
                            withAnimation(AppAnimation.stateChange) {
                                onSelectDate(day)
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
                scrollToSelected(proxy: proxy, animated: false, afterNanoseconds: 50_000_000)
            }
            .onChange(of: selectedDate) { _, newDate in
                syncRangeCenterIfNeeded(for: newDate)
                scrollToSelected(proxy: proxy, animated: true, afterNanoseconds: 30_000_000)
            }
        }
    }

    private var dayDates: [Date] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: rangeCenter)
        return (-dayRangeRadius...dayRangeRadius).compactMap {
            calendar.date(byAdding: .day, value: $0, to: start)
        }
    }

    private func syncRangeCenterIfNeeded(for date: Date) {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)
        let offset = calendar.dateComponents([.day], from: rangeCenter, to: day).day ?? 0
        if abs(offset) > dayRangeRadius - 30 {
            rangeCenter = day
        }
    }

    /// 並びの更新が画面に反映されるのを少し待ってからスクロールする。
    private func scrollToSelected(proxy: ScrollViewProxy, animated: Bool, afterNanoseconds delay: UInt64) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: delay)
            let day = Calendar.current.startOfDay(for: selectedDate)
            if animated {
                withAnimation(AppAnimation.stateChange) {
                    proxy.scrollTo(day, anchor: .center)
                }
            } else {
                proxy.scrollTo(day, anchor: .center)
            }
        }
    }
}

#Preview("WeekStrip") {
    @Previewable @State var selectedDate = Date()
    CalendarWeekStripView(selectedDate: selectedDate, onSelectDate: { selectedDate = $0 })
        .padding()
        .background(Color(.systemBackground))
}
