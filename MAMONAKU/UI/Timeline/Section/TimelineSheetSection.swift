import SwiftUI

/// カウントダウンの下に重なる、角丸のタイムラインシート。
///
/// 上部に日付ヘッダー、その下に 1 日分のタイムラインを置く。
/// 左右スワイプで前後の日へ移動でき、ピンチで時間軸を拡大・縮小できる。
struct TimelineSheetSection: View {
    @Environment(\.appTheme) private var theme

    let state: TimelineViewState
    weak var delegate: TimelineDelegate?

    /// ページング中の日。`state.selectedDate` と相互に同期する。
    @State private var pageDate: Date = Calendar.current.startOfDay(for: Date())
    /// ページとして並べる日付範囲の中心。スワイプ中に並びが変わらないよう、範囲外の日を選んだときだけ動かす。
    @State private var pageRangeCenter: Date = Calendar.current.startOfDay(for: Date())
    @State private var lastMagnification: CGFloat = 1.0
    @State private var hasScrolledToNowOnLaunch = false

    /// 中心から前後に並べる日数
    private static let pageRangeRadius = 14
    private static let currentTimeAnchorID = "currentTimeAnchor"
    private static let sheetShape = RoundedRectangle(cornerRadius: 30, style: .continuous)

    var body: some View {
        VStack(spacing: 10) {
            TimelineCalendarSection(
                selectedDate: state.selectedDate,
                onSelectDate: { delegate?.timelineDidSelectDate($0) },
                onTapDateLabel: { delegate?.timelineDidTapDateLabel() }
            )

            TabView(selection: $pageDate) {
                ForEach(pageDates, id: \.self) { date in
                    dayPage(for: date)
                        .tag(date)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .padding(.horizontal, TimelineLayout.horizontalPadding)
        .padding(.bottom, 40)
        .frame(maxWidth: .infinity)
        .background(theme.background, in: Self.sheetShape)
        .clipShape(Self.sheetShape)
        .shadow(color: theme.shadow, radius: 15, x: 0, y: -6)
        .onAppear {
            pageDate = state.selectedDate
            pageRangeCenter = state.selectedDate
        }
        .onChange(of: state.selectedDate) { _, selectedDate in
            if !isWithinPageRange(selectedDate) {
                pageRangeCenter = selectedDate
            }
            if selectedDate != pageDate {
                pageDate = selectedDate
            }
        }
        .onChange(of: pageDate) { _, pageDate in
            delegate?.timelineDidSelectDate(pageDate)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - 1 日分のページ

    private func dayPage(for date: Date) -> some View {
        let allDayItems = state.allDayItems(on: date)

        return ScrollViewReader { scrollProxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 8) {
                    if !allDayItems.isEmpty {
                        AllDayTagRowView(items: allDayItems)
                    }

                    HStack(alignment: .top, spacing: 0) {
                        TimelineTimeColumnView(layout: state.layout)
                        GeometryReader { geometry in
                            TimelineDaySection(
                                state: state,
                                date: date,
                                width: geometry.size.width,
                                currentTimeAnchorID: Self.currentTimeAnchorID,
                                delegate: delegate
                            )
                        }
                        .frame(height: state.layout.dayHeight)
                    }
                    .simultaneousGesture(magnificationGesture)
                }
                // 24 時の下にも余白を取り、深夜の時間帯を画面の上の方までスクロールできるようにする
                .padding(.bottom, 500)
            }
            .onAppear {
                guard !hasScrolledToNowOnLaunch, Calendar.current.isDateInToday(date) else { return }
                hasScrolledToNowOnLaunch = true
                scrollToCurrentTime(on: date, with: scrollProxy)
            }
            .onChange(of: state.scrollToNowRequestID) { _, requestID in
                guard requestID != nil else { return }
                scrollToCurrentTime(on: date, with: scrollProxy)
            }
        }
    }

    private var pageDates: [Date] {
        (-Self.pageRangeRadius...Self.pageRangeRadius).compactMap { offset in
            Calendar.current.date(byAdding: .day, value: offset, to: pageRangeCenter)
        }
    }

    private func isWithinPageRange(_ date: Date) -> Bool {
        let days = Calendar.current.dateComponents([.day], from: pageRangeCenter, to: date).day ?? 0
        return abs(days) <= Self.pageRangeRadius
    }

    // MARK: - ジェスチャ・スクロール

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { magnification in
                delegate?.timelineDidPinch(by: magnification / lastMagnification)
                lastMagnification = magnification
            }
            .onEnded { _ in
                lastMagnification = 1.0
            }
    }

    /// 現在時刻の少し上が見える位置までスクロールする（今日のページのみ）。
    private func scrollToCurrentTime(on date: Date, with scrollProxy: ScrollViewProxy) {
        guard Calendar.current.isDateInToday(date) else { return }
        Task { @MainActor in
            // レイアウトが確定するのを少し待つ
            try? await Task.sleep(nanoseconds: 50_000_000)
            withAnimation(.easeInOut(duration: 0.25)) {
                scrollProxy.scrollTo(Self.currentTimeAnchorID, anchor: UnitPoint(x: 0.5, y: 0.1))
            }
        }
    }
}

#Preview("TimelineSheetSection") {
    let today = Calendar.current.startOfDay(for: Date())
    var state = TimelineViewState(selectedDate: today)
    state.items = [
        TimelineItem(title: "Wake up", durationMinutes: 30, startMinutes: 9 * 60, dropDate: today, priority: .low),
        TimelineItem(title: "Workout", durationMinutes: 60, startMinutes: 10 * 60, dropDate: today),
        TimelineItem(title: "All day", durationMinutes: 30, dropDate: today, priority: .high, isAllDay: true)
    ]
    return TimelineSheetSection(state: state, delegate: nil)
}
