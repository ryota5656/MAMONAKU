import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct WhiteSheetView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @ObservedObject var viewModel: TimelineViewModel
    @Binding var sheetHeight: CGFloat
    var isSettingsHighlighted: Bool = false
    var onOpenSettings: () -> Void = {}
    @State private var lastMagnification: CGFloat = 1.0
    @State private var tabSelection: Date = Calendar.current.startOfDay(for: Date())
    /// スワイプで配列がずれないよう、TabView の日付範囲の中心を固定する（カレンダーで遠い日を選んだときだけ更新）
    @State private var datesForTabCenter: Date = Calendar.current.startOfDay(for: Date())
    private let currentTimeAnchorID = "currentTimeAnchor"
    @State private var hasCenteredCurrentTimeOnLaunch = false

    private func startOfDay(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    private func isDateWithinTabWindow(_ date: Date, center: Date) -> Bool {
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: center, to: date).day ?? 0
        return days >= -14 && days <= 14
    }

    var body: some View {
        GeometryReader { proxy in
            let sheetShape = RoundedRectangle(cornerRadius: 30, style: .continuous)

            VStack(spacing: 10) {
                CalendarHeaderView(
                    selectedDate: $viewModel.selectedDate,
                    isTwoDayView: $viewModel.isTwoDayView,
                    isSettingsHighlighted: isSettingsHighlighted,
                    onOpenSettings: onOpenSettings
                )
                
                TabView(selection: $tabSelection) {
                    ForEach(datesForTab, id: \.self) { date in
                        let allDayItems = viewModel.allDayItems(for: date)
                        ScrollViewReader { scrollProxy in
                            ScrollView(.vertical, showsIndicators: false) {
                                VStack(alignment: .leading, spacing: 8) {
                                    if !allDayItems.isEmpty {
                                        // 全日の予定のタグ表示
                                        allDayTagRow(items: allDayItems)
                                    }

                                    HStack(alignment: .top, spacing: 0) {
                                        timeColumn
                                        singleDayTimelineColumn(date: date)
                                    }
                                    .simultaneousGesture(magnificationGesture)
                                }
                                .padding(.bottom, 500) //GAD入れても良い
                            }
                            .onAppear {
                                centerCurrentTimeIfNeeded(on: date, with: scrollProxy)
                            }
                        }
                        .tag(date)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .padding(.horizontal, viewModel.timelinePadding)
            .padding(.bottom, 40)
            .frame(maxWidth: .infinity)
            .background(AppColors.background(palette: themeManager.theme, environmentScheme: colorScheme), in: sheetShape)
            .clipShape(sheetShape)
            .shadow(color: AppColors.shadow(palette: themeManager.theme, environmentScheme: colorScheme), radius: 15, x: 0, y: -6)
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: viewModel.chipsExpanded)
            .animation(.spring(response: 0.28, dampingFraction: 0.9), value: sheetHeight)
            .onChange(of: viewModel.chipsExpanded) { _, isExpanded in
            }
            .onAppear {
                let start = startOfDay(viewModel.selectedDate)
                tabSelection = start
                datesForTabCenter = start
            }
            .onChange(of: viewModel.selectedDate) { _, newDate in
                let start = startOfDay(newDate)
                if !isDateWithinTabWindow(start, center: datesForTabCenter) {
                    datesForTabCenter = start
                }
                if start != tabSelection { tabSelection = start }
            }
            .onChange(of: tabSelection) { _, newDate in
                viewModel.selectedDate = newDate
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private func clampedSheetHeight(_ proposed: CGFloat, in available: CGFloat) -> CGFloat {
        let minHeight = max(360, available * 0.45)
        let maxHeight = available + 20
        return min(max(proposed, minHeight), maxHeight)
    }

    private var timeColumn: some View {
        TimelineTimeColumnView(
            timeColumnWidth: viewModel.timeColumnWidth,
            hourHeight: viewModel.hourHeight,
            zoomScale: viewModel.zoomScale,
            textColor: AppColors.textSecondary(palette: themeManager.theme, environmentScheme: colorScheme)
        )
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let delta = value / lastMagnification
                lastMagnification = value
                let nextScale = clampZoom(viewModel.zoomScale * delta)
                viewModel.zoomScale = nextScale
            }
            .onEnded { _ in
                lastMagnification = 1.0
            }
    }

    private func clampZoom(_ value: CGFloat) -> CGFloat {
        min(max(value, 0.6), 2.0)
    }

    private var datesForTab: [Date] {
        let cal = Calendar.current
        let center = datesForTabCenter
        return (-14...14).compactMap { offset in
            cal.date(byAdding: .day, value: offset, to: center)
        }
    }

    // MARK: - １日分のすべてのカラム
    private func singleDayTimelineColumn(date: Date) -> some View {
        let height = viewModel.hourHeight * viewModel.zoomScale * 24
        return GeometryReader { geo in
            TimelineDayColumnView(
                viewModel: viewModel,
                date: date,
                width: geo.size.width,
                height: height,
                currentTimeAnchorID: currentTimeAnchorID
            )
        }
        .frame(height: viewModel.hourHeight * viewModel.zoomScale * 24)
    }

    private func allDayTagRow(items: [TimelineItem]) -> some View {
        AllDayTagRowView(
            items: items,
            timeColumnWidth: viewModel.timeColumnWidth,
            textColor: AppColors.textPrimary(palette: themeManager.theme, environmentScheme: colorScheme),
            chipBackground: AppColors.settingsListBackground(palette: themeManager.theme, environmentScheme: colorScheme)
        )
    }

    private func isSameDay(_ lhs: Date?, _ rhs: Date) -> Bool {
        guard let lhs else { return false }
        return Calendar.current.isDate(lhs, inSameDayAs: rhs)
    }

    private func centerCurrentTimeIfNeeded(on date: Date, with scrollProxy: ScrollViewProxy) {
        guard !hasCenteredCurrentTimeOnLaunch else { return }
        guard Calendar.current.isDateInToday(date) else { return }
        Task { @MainActor in
            for delay in [50_000_000] {
                try? await Task.sleep(nanoseconds: UInt64(delay))
                withAnimation(.easeInOut(duration: 0.2)) {
                    scrollProxy.scrollTo(currentTimeAnchorID, anchor: UnitPoint(x: 0.5, y: 0.1))
                }
            }
            hasCenteredCurrentTimeOnLaunch = true
        }
    }
}

#Preview("WhiteSheetView") {
    let items = [
        TimelineItem(title: "Wake up", durationMinutes: 30, startMinutes: 9 * 60, dropDate: Date(), priority: .low),
        TimelineItem(title: "Workout", durationMinutes: 60, startMinutes: 10 * 60, dropDate: Date(), priority: .medium),
        TimelineItem(title: "All day", durationMinutes: 30, startMinutes: nil, dropDate: Date(), priority: .high, isAllDay: true)
    ]
    let vm = TimelineViewModel(initialItems: items, enablePolling: false)
    return WhiteSheetView(
        viewModel: vm,
        sheetHeight: .constant(600),
        isSettingsHighlighted: true,
        onOpenSettings: {}
    )
    .environmentObject(ThemeManager())
}

