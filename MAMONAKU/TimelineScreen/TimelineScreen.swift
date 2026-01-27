import SwiftUI
import UniformTypeIdentifiers

struct TimelineScreen: View {
    @StateObject private var viewModel = TimelineViewModel()
    @State private var sheetHeight: CGFloat = 0

    init() {
        _viewModel = StateObject(wrappedValue: TimelineViewModel())
    }

    init(items: [TimelineItem]) {
        let viewModel = TimelineViewModel()
        viewModel.items = items
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {

                VStack(alignment: .leading, spacing: 12) {
                    countdownHeader
                }
                .padding(.top, 24)
                .frame(maxWidth: .infinity, alignment: .leading)

                whiteSheet
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
//            .background(Color.black.opacity(0.1))
            .simultaneousGesture(
                TapGesture()
                    .onEnded {
                        if viewModel.editMode.isEditing {
                            viewModel.editMode = .inactive
                        }
                    }
            )
            .onAppear {
                viewModel.updateLiveActivity()
            }
            .onChange(of: viewModel.items) { _, _ in
                viewModel.updateLiveActivity()
            }
        }
    }



    private var timeColumn: some View {
        VStack(spacing: 0) {
            ForEach(0...24, id: \.self) { hour in
                Text(String(format: "%02d:00", hour))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(
                        width: viewModel.timeColumnWidth,
                        height: viewModel.hourHeight,
                        alignment: .topLeading
                    )
            }
        }
    }

    private var timelineColumn: some View {
        GeometryReader { geo in
            let height = viewModel.hourHeight * 24
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
        .frame(height: viewModel.hourHeight * 24)
        .gesture(timelineSwipeGesture)
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

        return ZStack(alignment: .topLeading) {
            timelineGrid(width: width, height: height)

            ForEach(items) { item in
                if let startMinutes = item.startMinutes {
                    ScheduleItemView(
                        item: item,
                        isEditing: viewModel.editMode.isEditing,
                        onEnterEdit: {
                            if !viewModel.editMode.isEditing {
                                viewModel.editMode = .active
                            }
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
                    .frame(
                        width: itemWidth,
                        height: viewModel.heightForDuration(item.durationMinutes)
                    )
                    .offset(x: 0, y: viewModel.yOffset(for: startMinutes))
                }
            }

            if let preview = viewModel.dropPreview, isSameDay(preview.dropDate, date) {
                ScheduleItemPreviewView(item: preview)
                    .frame(
                        width: itemWidth,
                        height: viewModel.heightForDuration(preview.durationMinutes)
                    )
                    .offset(x: 0, y: viewModel.yOffset(for: preview.startMinutes ?? 0))
            }

            if let preview = viewModel.movePreview, isSameDay(preview.dropDate, date) {
                ScheduleItemPreviewView(item: preview)
                    .frame(
                        width: itemWidth,
                        height: viewModel.heightForDuration(preview.durationMinutes)
                    )
                    .offset(x: 0, y: viewModel.yOffset(for: preview.startMinutes ?? 0))
            }

            if let preview = viewModel.resizePreview, isSameDay(preview.dropDate, date) {
                ScheduleItemPreviewView(item: preview)
                    .frame(
                        width: itemWidth,
                        height: viewModel.heightForDuration(preview.durationMinutes)
                    )
                    .offset(x: 0, y: viewModel.yOffset(for: preview.startMinutes ?? 0))
            }

            if Calendar.current.isDate(date, inSameDayAs: Date()) {
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

    private func isSameDay(_ lhs: Date?, _ rhs: Date) -> Bool {
        guard let lhs else { return false }
        return Calendar.current.isDate(lhs, inSameDayAs: rhs)
    }

    private var whiteSheet: some View {
        GeometryReader { proxy in
            let available = proxy.size.height
            let topPadding: CGFloat = viewModel.chipsExpanded ? 24 : 24
            let initialHeight = available * 0.82
            let expandedHeight = available * 1
            let collapsedHeight = available * 0.82
            let sheetShape = RoundedRectangle(cornerRadius: 50, style: .continuous)
            let clampedHeight = clampedSheetHeight(
                sheetHeight == 0 ? initialHeight : sheetHeight,
                in: available
            )

            VStack(spacing: 16) {
                CalendarHeaderView(
                    selectedDate: $viewModel.selectedDate,
                    isTwoDayView: $viewModel.isTwoDayView
                )
                ScrollView {
                    HStack(alignment: .top, spacing: 0) {
                        timeColumn
                        timelineColumn
                    }
                }

                TimelineStockView(
                    items: viewModel.items,
                    chipsExpanded: $viewModel.chipsExpanded,
                    dragItemID: $viewModel.dragItemID,
                    onAdd: { title, durationMinutes in
                        viewModel.addStockItem(title: title, durationMinutes: durationMinutes)
                    },
                    onMove: { from, to, visibleCount in
                        viewModel.moveChips(from: from, to: to, visibleCount: visibleCount)
                    },
                    onDelete: { id in
                        viewModel.deleteItem(id: id)
                    }
                )
            }
            .padding(.top, topPadding)
            .padding(.horizontal, viewModel.timelinePadding)
            .padding(.bottom, 40)
            .frame(height: clampedHeight)
            .frame(maxWidth: .infinity)
            .background(AppColors.background, in: sheetShape)
            .environment(\.colorScheme, .light)
            .clipShape(sheetShape)
            .shadow(color: .black.opacity(0.12), radius: 20, x: 0, y: -6)
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: viewModel.chipsExpanded)
            .animation(.spring(response: 0.28, dampingFraction: 0.9), value: sheetHeight)
            .onAppear {
                if sheetHeight == 0 {
                    sheetHeight = clampedHeight
                }
            }
            .onChange(of: viewModel.chipsExpanded) { _, isExpanded in
                let target = isExpanded ? expandedHeight : collapsedHeight
                sheetHeight = clampedSheetHeight(target, in: available)
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

    private func currentTimeLine(width: CGFloat) -> some View {
        TimelineView(.animation) { context in
            let minutes = viewModel.minutesSinceMidnight(date: context.date)
            let y = viewModel.yOffset(for: minutes)

            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.red.opacity(0.8))
                    .frame(width: width, height: 2)
                Text(viewModel.currentTimeText(date: context.date))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.red)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.systemBackground).opacity(0.9))
                    .cornerRadius(4)
                    .offset(x: 4, y: -10)
            }
            .offset(y: y)
        }
    }

    private func timelineGrid(width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(AppColors.background)
                .frame(width: width, height: height)

            RoundedRectangle(cornerRadius: 30)
                .fill(Color.black.opacity(0.1))
                .frame(width:1, height: height)
                .offset(x: 3)
            
            ForEach(0...24, id: \.self) { hour in
                Rectangle()
                    .fill(Color.black.opacity(0.1))
                    .frame(width: 10, height: 1)
                    .offset(y: CGFloat(hour) * viewModel.hourHeight)
            }
        }
        .cornerRadius(8)
    }

    private var countdownHeader: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let nowSeconds = secondsSinceMidnight(date: context.date)
            let next = nextItem(afterSeconds: nowSeconds)

            let targetSeconds = (next?.startMinutes ?? 0) * 60
            let diff = max(0, targetSeconds - nowSeconds)

            VStack(alignment: .center, spacing: 10) {
                Text("次の予定まで")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.black.opacity(0.6))

                if next != nil {
                    CountdownDisplay(seconds: diff)
                } else {
                    Text("予定なし")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.black.opacity(0.6))
                }

                if let next {
                    Text("\(next.title) \(minutesToTime(next.startMinutes ?? 0))")
                        .font(.system(size: 12))
                        .foregroundColor(.black.opacity(0.5))
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private func secondsSinceMidnight(date: Date) -> Int {
        let cal = Calendar.current
        let comps = cal.dateComponents([.hour, .minute, .second], from: date)
        let h = comps.hour ?? 0
        let m = comps.minute ?? 0
        let s = comps.second ?? 0
        return (h * 3600) + (m * 60) + s
    }

    private func nextItem(afterSeconds seconds: Int) -> TimelineItem? {
        let startMinutes = Int(ceil(Double(seconds) / 60.0))
        let candidates: [(TimelineItem, Int)] = viewModel.itemsForSelectedDate.compactMap { item in
            guard let minutes = item.startMinutes else { return nil }
            return (item, minutes)
        }
        return candidates
            .filter { $0.1 >= startMinutes }
            .min(by: { $0.1 < $1.1 })?
            .0
    }

    private func formatCountdown(seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }

    private func countdownComponents(seconds: Int) -> (String, String, String) {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        return (String(format: "%02d", h), String(format: "%02d", m), String(format: "%02d", s))
    }

    private func minutesToTime(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        return String(format: "%02d:%02d", h, m)
    }
}

private struct CountdownDisplay: View {
    let seconds: Int

    var body: some View {
        let parts = components
        HStack(spacing: 12) {
            CountdownDigit(text: parts.h)
            CountdownSeparator()
            CountdownDigit(text: parts.m)
            CountdownSeparator()
            CountdownDigit(text: parts.s)
        }
        .animation(.easeInOut(duration: 0.2), value: seconds)
    }

    private var components: (h: String, m: String, s: String) {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        return (
            String(format: "%02d", h),
            String(format: "%02d", m),
            String(format: "%02d", s)
        )
    }
}

private struct CountdownDigit: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.custom("DevanagariSangamMN-Bold", size: 44))
            .foregroundColor(Color.black.opacity(0.9))
            .monospacedDigit()
            .contentTransition(.numericText())
    }
}

private struct CountdownSeparator: View {
    var body: some View {
        Text(":")
            .font(.system(size: 34, weight: .light, design: .rounded))
            .foregroundColor(Color.black)
    }
}

private struct TimelineDropDelegate: DropDelegate {
    let hourHeight: CGFloat
    let minuteStep: Int
    let timelineHeight: CGFloat
    @Binding var preview: TimelineItem?
    @Binding var previewItemID: UUID?
    @Binding var dragItemID: UUID?
    let onPreview: (UUID, CGPoint) -> Void
    let onDrop: (UUID, CGPoint) -> Void
    @State private var isLoadingItemID = false

//    func dropEntered(info: DropInfo) {
//        loadDurationIfNeeded(from: info)
//    }

    func performDrop(info: DropInfo) -> Bool {
        defer {
            DispatchQueue.main.async {
                preview = nil
                previewItemID = nil
                dragItemID = nil
            }
        }

        guard let provider = info.itemProviders(for: [UTType.text]).first else { return false }

        provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { item, _ in
            guard let itemID = parseItemID(from: item) else { return }

            DispatchQueue.main.async {
                let location = info.location
                onDrop(itemID, location)
            }
        }
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        if let itemID = previewItemID ?? dragItemID {
            onPreview(itemID, info.location)
        } else {
            loadItemIDIfNeeded(from: info)
        }
        return DropProposal(operation: .copy)
    }

    func dropExited(info: DropInfo) {
        preview = nil
        previewItemID = nil
    }

    private func loadItemIDIfNeeded(from info: DropInfo) {
        guard !isLoadingItemID, previewItemID == nil,
              let provider = info.itemProviders(for: [UTType.text]).first
        else { return }

        isLoadingItemID = true
        provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { item, _ in
            defer { isLoadingItemID = false }
            guard let itemID = parseItemID(from: item) else { return }

            DispatchQueue.main.async {
                previewItemID = itemID
                onPreview(itemID, info.location)
            }
        }
    }

    private func parseItemID(from item: NSSecureCoding?) -> UUID? {
        if let data = item as? Data,
           let text = String(data: data, encoding: .utf8) {
            return UUID(uuidString: text.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        if let text = item as? String {
            return UUID(uuidString: text.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        if let text = item as? NSString {
            return UUID(uuidString: text.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return nil
    }
}

#Preview{
    ContentView()
}
#Preview("scheduleItemPreview"){
    ScheduleItemPreviewView(
        item: TimelineItem(title: "Preview", durationMinutes: 60, startMinutes: 120)
    )
    .frame(height: 100)
    .padding(20)
}


#Preview("timeline with items") {
    TimelineScreen(items: [
        TimelineItem(title: "Wake up", durationMinutes: 15, startMinutes: 2 * 60, dropDate: Date()),
        TimelineItem(title: "Workout", durationMinutes: 60, startMinutes: 2 * 60 + 45, dropDate: Date()),
        TimelineItem(title: "Breakfast", durationMinutes: 30, startMinutes: 4 * 60, dropDate: Date()),
        TimelineItem(title: "Study", durationMinutes: 120, startMinutes: 5 * 60, dropDate: Date())
    ])
}
