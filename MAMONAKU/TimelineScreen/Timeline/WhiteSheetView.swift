import SwiftUI
import UniformTypeIdentifiers

struct WhiteSheetView: View {
    @ObservedObject var viewModel: TimelineViewModel
    @Binding var sheetHeight: CGFloat
    @State private var lastMagnification: CGFloat = 1.0
    private let currentTimeAnchorID = "currentTimeAnchor"

    var body: some View {
        GeometryReader { proxy in
            let sheetShape = RoundedRectangle(cornerRadius: 30, style: .continuous)

            VStack(spacing: 16) {
                CalendarHeaderView(
                    selectedDate: $viewModel.selectedDate,
                    isTwoDayView: $viewModel.isTwoDayView
                )
                
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 0) {
                            timeColumn
                            timelineColumn
                        }
                        .background(
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if viewModel.editMode.isEditing {
                                        viewModel.editMode = .inactive
                                    }
                                }
                        )
                        .simultaneousGesture(magnificationGesture)
                    }
                }
            }
            .padding(.horizontal, viewModel.timelinePadding)
            .padding(.bottom, 40)
            .frame(maxWidth: .infinity)
            .background(AppColors.background, in: sheetShape)
//            .environment(\.colorScheme, .light)
            .clipShape(sheetShape)
            .shadow(color: AppColors.shadow.opacity(0.5), radius: 15, x: 0, y: -6)
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: viewModel.chipsExpanded)
            .animation(.spring(response: 0.28, dampingFraction: 0.9), value: sheetHeight)
            .onChange(of: viewModel.chipsExpanded) { _, isExpanded in
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
        let rowHeight = viewModel.hourHeight * viewModel.zoomScale
        return VStack(spacing: 0) {
            ForEach(0...24, id: \.self) { hour in
                Text(String(format: "%02d:00", hour))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(
                        width: viewModel.timeColumnWidth,
                        height: rowHeight,
                        alignment: .topLeading
                    )
            }
        }
    }

    private var timelineColumn: some View {
        GeometryReader { geo in
            let height = viewModel.hourHeight * viewModel.zoomScale * 24
            let totalWidth = geo.size.width
            let dates = timelineDates
            let spacing: CGFloat = 0
            let columnWidth = (totalWidth - spacing * CGFloat(max(0, dates.count - 1))) / CGFloat(max(1, dates.count))

            HStack(alignment: .top, spacing: spacing) {
                ForEach(dates, id: \.self) { date in
                    dayTimelineColumn(date: date, width: columnWidth, height: height)
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: dates.count)
        }
        .frame(height: viewModel.hourHeight * viewModel.zoomScale * 24)
        .gesture(timelineSwipeGesture)
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

    private var timelineSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 30)
            .onEnded { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height
                guard abs(horizontal) > abs(vertical), abs(horizontal) > 60 else { return }
                if horizontal < 0 {
                    advanceTimeline()
                } else {
                    retreatTimeline()
                }
            }
    }

    private func advanceTimeline() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            if viewModel.isTwoDayView {
                viewModel.selectedDate = addDays(1, to: viewModel.selectedDate)
                viewModel.isTwoDayView = false
            } else {
                viewModel.isTwoDayView = true
            }
        }
    }

    private func retreatTimeline() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            if viewModel.isTwoDayView {
                viewModel.isTwoDayView = false
            } else {
                viewModel.selectedDate = addDays(-1, to: viewModel.selectedDate)
                viewModel.isTwoDayView = true
            }
        }
    }

    private func addDays(_ value: Int, to date: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: value, to: date) ?? date
    }

    private var timelineDates: [Date] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: viewModel.selectedDate)
        if viewModel.isTwoDayView {
            let next = cal.date(byAdding: .day, value: 1, to: start) ?? start
            return [start, next]
        }
        return [start]
    }

    private func dayTimelineColumn(date: Date, width: CGFloat, height: CGFloat) -> some View {
        let items = viewModel.items(for: date)
        let itemWidth = max(80, width - (viewModel.timelinePadding * 0.5))
        let showTimeThreshold: CGFloat = 31

        return ZStack(alignment: .topLeading) {
            timelineGrid(width: width, height: height)

            ForEach(items) { item in
                if let startMinutes = item.startMinutes {
                    let itemHeight = viewModel.heightForDuration(item.durationMinutes)
                    let showTimeRange = itemHeight >= showTimeThreshold
                    ScheduleItemView(
                        item: item,
                        isEditing: viewModel.editMode.isEditing,
                        showTimeRange: showTimeRange,
                        onEnterEdit: {
                            viewModel.editMode = viewModel.editMode.isEditing ? .inactive : .active
                        },
                        onMovePreview: { deltaY in
                            viewModel.updateMovePreview(item: item, deltaY: deltaY)
                        },
                        onMoveEnd: { deltaY in
                            viewModel.commitMove(item: item, deltaY: deltaY)
                        },
                        onResizePreview: { deltaY in
                            viewModel.updateResizePreview(item: item, deltaY: deltaY)
                        },
                        onResizeEnd: { deltaY in
                            viewModel.commitResize(item: item, deltaY: deltaY)
                        },
                        onDelete: {
                            viewModel.deleteItem(id: item.id)
                        }
                    )
                    .padding(.trailing, 7)
                    .frame(
                        width: .infinity,
                        height: itemHeight
                    )
                    .offset(x: 0, y: viewModel.yOffset(for: startMinutes))
                }
            }

            if let preview = viewModel.dropPreview, isSameDay(preview.dropDate, date) {
                let previewHeight = viewModel.heightForDuration(preview.durationMinutes)
                ScheduleItemPreviewView(
                    item: preview,
                    showTimeRange: previewHeight >= showTimeThreshold
                )
                .padding(.trailing, 7)
                .frame(
                    width: .infinity,
                    height: previewHeight
                )
                .offset(x: 0, y: viewModel.yOffset(for: preview.startMinutes ?? 0))
                .zIndex(0)
                .allowsHitTesting(false)
            }

            if let preview = viewModel.movePreview, isSameDay(preview.dropDate, date) {
                let previewHeight = viewModel.heightForDuration(preview.durationMinutes)
                ScheduleItemPreviewView(
                    item: preview,
                    showTimeRange: previewHeight >= showTimeThreshold
                )
                .padding(.trailing, 7)
                .frame(
                    width: .infinity,
                    height: previewHeight
                )
                .offset(x: 0, y: viewModel.yOffset(for: preview.startMinutes ?? 0))
                .zIndex(0)
                .allowsHitTesting(false)
            }

            if let preview = viewModel.resizePreview, isSameDay(preview.dropDate, date) {
                let previewHeight = viewModel.heightForDuration(preview.durationMinutes)
                ScheduleItemPreviewView(
                    item: preview,
                    showTimeRange: previewHeight >= showTimeThreshold
                )
                .frame(
                    width: itemWidth,
                    height: previewHeight
                )
                .offset(x: 0, y: viewModel.yOffset(for: preview.startMinutes ?? 0))
                .zIndex(0)
                .allowsHitTesting(false)
            }

            if Calendar.current.isDate(date, inSameDayAs: Date()) {
                Color.clear
                    .frame(width: 1, height: 1)
                    .offset(x: 0, y: viewModel.yOffset(for: viewModel.minutesSinceMidnight(date: Date())))
                    .id(currentTimeAnchorID)
                currentTimeLine(width: width)
            }
        }
        .frame(width: width, height: height)
        .coordinateSpace(name: "timeline")
        .onDrop(
            of: [UTType.text],
            delegate: TimelineDropDelegate(
                hourHeight: viewModel.hourHeight,
                minuteStep: viewModel.minuteStep,
                timelineHeight: height,
                preview: $viewModel.dropPreview,
                previewItemID: $viewModel.previewItemID,
                dragItemID: $viewModel.dragItemID,
                onPreview: { itemID, location in
                    guard let item = viewModel.items.first(where: { $0.id == itemID }) else { return }
                    viewModel.updatePreview(item: item, dropY: location.y, on: date)
                },
                onDrop: { itemID, location in
                    guard let item = viewModel.items.first(where: { $0.id == itemID }) else { return }
                    viewModel.addItem(item: item, dropY: location.y, on: date)
                }
            )
        )
    }

    private func currentTimeLine(width: CGFloat) -> some View {
        TimelineView(.animation) { context in
            let minutes = viewModel.minutesSinceMidnight(date: context.date)
            let y = viewModel.yOffset(for: minutes)

            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.red.opacity(0.8))
                    .frame(width: width, height: 2)
                    .offset(y: -10)
                Text(viewModel.currentTimeText(date: context.date))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.red)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.systemBackground).opacity(0.9))
                    .cornerRadius(4)
                    .offset(x: 4, y: -20)
            }
            .offset(y: y)
        }
    }

    private func timelineGrid(width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(width: width, height: height)

            RoundedRectangle(cornerRadius: 30)
                .fill(Color.black.opacity(0.1))
                .frame(width: 1, height: height)
                .offset(x: 7)

            ForEach(0...24, id: \.self) { hour in
                Rectangle()
                    .fill(Color.black.opacity(0.1))
                    .frame(width: 10, height: 1)
                    .offset(y: CGFloat(hour) * viewModel.hourHeight * viewModel.zoomScale)
            }
        }
//        .cornerRadius(8)
    }

    private func isSameDay(_ lhs: Date?, _ rhs: Date) -> Bool {
        guard let lhs else { return false }
        return Calendar.current.isDate(lhs, inSameDayAs: rhs)
    }
}

#Preview("timeline with items") {
    TimelineScreen(items: [
        TimelineItem(title: "Wake up", durationMinutes: 15, startMinutes: 11 * 60, dropDate: Date()),
        TimelineItem(title: "Workout", durationMinutes: 60, startMinutes: 2 * 60 + 45, dropDate: Date()),
        TimelineItem(title: "Breakfast", durationMinutes: 30, startMinutes: 4 * 60, dropDate: Date()),
        TimelineItem(title: "Study", durationMinutes: 120, startMinutes: 5 * 60, dropDate: Date())
    ])
}
