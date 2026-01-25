import SwiftUI
import UniformTypeIdentifiers

struct TimelineScreen: View {
    @StateObject private var viewModel = TimelineViewModel()
    @State private var sheetHeight: CGFloat = 0

    init() {
        _viewModel = StateObject(wrappedValue: TimelineViewModel())
    }

    init(items: [ScheduleItem]) {
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
            .background(AppColors.background)
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
            let width = geo.size.width

            ZStack(alignment: .topLeading) {
                timelineGrid(width: width, height: height)

                ForEach(viewModel.items) { item in
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
                            width: max(80, width - viewModel.timelinePadding),
                            height: viewModel.heightForDuration(item.durationMinutes)
                        )
                        .offset(x: 0, y: viewModel.yOffset(for: item.startMinutes))
                }
                

                if let preview = viewModel.dropPreview {
                    ScheduleItemPreviewView(item: preview)
                        .frame(
                            width: max(80, width - viewModel.timelinePadding),
                            height: viewModel.heightForDuration(preview.durationMinutes)
                        )
                        .offset(x: 0, y: viewModel.yOffset(for: preview.startMinutes))
                }

                if let preview = viewModel.movePreview {
                    ScheduleItemPreviewView(item: preview)
                        .frame(
                            width: max(80, width - viewModel.timelinePadding),
                            height: viewModel.heightForDuration(preview.durationMinutes)
                        )
                        .offset(x: 0, y: viewModel.yOffset(for: preview.startMinutes))
                }

                if let preview = viewModel.resizePreview {
                    ScheduleItemPreviewView(item: preview)
                        .frame(
                            width: max(80, width - viewModel.timelinePadding),
                            height: viewModel.heightForDuration(preview.durationMinutes)
                        )
                        .offset(x: 0, y: viewModel.yOffset(for: preview.startMinutes))
                }

                currentTimeLine(width: width)
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
                    previewDuration: $viewModel.previewDuration,
                    dragDuration: $viewModel.dragDuration,
                    onPreview: { duration, location in
                        viewModel.updatePreview(duration: duration, dropY: location.y)
                    },
                    onDrop: { duration, location in
                        viewModel.addItem(duration: duration, dropY: location.y)
                    }
                )
            )
        }
        .frame(height: viewModel.hourHeight * 24)
    }

    private var whiteSheet: some View {
        GeometryReader { proxy in
            let available = proxy.size.height
            let topPadding: CGFloat = viewModel.chipsExpanded ? 24 : 80
            let initialHeight = available * 0.82
            let expandedHeight = available * 1
            let collapsedHeight = available * 0.82
            let sheetShape = RoundedRectangle(cornerRadius: 50, style: .continuous)
            let clampedHeight = clampedSheetHeight(
                sheetHeight == 0 ? initialHeight : sheetHeight,
                in: available
            )

            VStack(spacing: 16) {
                ScrollView {
                    HStack(alignment: .top, spacing: 0) {
                        timeColumn
                        timelineColumn
                    }
                }

                taskArea
            }
            .padding(.top, topPadding)
            .padding(.horizontal, viewModel.timelinePadding)
            .padding(.bottom, 40)
            .frame(height: clampedHeight)
            .frame(maxWidth: .infinity)
            .background(AppColors.background, in: sheetShape)
            .environment(\.colorScheme, .light)
            .clipShape(sheetShape)
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

    private var taskArea: some View {
        let rows = viewModel.chipsExpanded ? 5 : 0
        let visible = Array(viewModel.chipItemsData.prefix(rows))
        let rowHeight: CGFloat = 44

        return VStack(spacing: 8) {
            HStack {
                Text("TASK")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        viewModel.chipsExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(viewModel.chipsExpanded ? "閉じる" : "拡張")
                        Image(systemName: viewModel.chipsExpanded ? "chevron.down" : "chevron.up")
                    }
                    .font(.system(size: 12, weight: .semibold))
                }
                Button {
                    viewModel.editMode = viewModel.editMode.isEditing ? .inactive : .active
                } label: {
                    Text(viewModel.editMode.isEditing ? "完了" : "並べ替え")
                        .font(.system(size: 12, weight: .semibold))
                }
            }

            if !visible.isEmpty {
            List {
                ForEach(visible) { chip in
                    chipRow(for: chip)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
                .onMove(perform: { from, to in
                        viewModel.moveChips(from: from, to: to, visibleCount: visible.count)
                })
            }
            .listStyle(.plain)
                .environment(\.editMode, $viewModel.editMode)
            .frame(height: rowHeight * CGFloat(visible.count))
            }
        }
        .padding(16)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.black.opacity(0.12), lineWidth: 1)
        )
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: viewModel.chipsExpanded)
    }

    @ViewBuilder
    private func chipRow(for chip: ChipItemData) -> some View {
        HStack {
            switch chip.kind {
            case .duration(let minutes):
                DraggableChip(title: chip.title, durationMinutes: minutes, dragDuration: $viewModel.dragDuration)
            case .quickAdd:
                QuickAddChip(title: chip.title, action: viewModel.addOneMinuteLaterItem)
            }
            Spacer()
        }
    }

    struct DraggableChip: View {
        let title: String
        let durationMinutes: Int
        @Binding var dragDuration: Int?

        var body: some View {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .cornerRadius(8)
                .onDrag {
                    dragDuration = durationMinutes
                    return NSItemProvider(object: "\(durationMinutes)" as NSString)
                }
        }
    }

    struct QuickAddChip: View {
        let title: String
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .cornerRadius(8)
            }
        }
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

            VStack(alignment: .center, spacing: 8) {
                Text("次の予定まで")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.black)

                if let next {
                    let targetSeconds = next.startMinutes * 60
                    let diff = max(0, targetSeconds - nowSeconds)
                    HStack(spacing: 8) {
                        Text(formatCountdown(seconds: diff))
                            .font(.system(size: 20, design: .monospaced))
                            .foregroundColor(.black)
                        Text("(\(next.title) \(minutesToTime(next.startMinutes)))")
                            .font(.system(size: 12))
                            .foregroundColor(.black.opacity(0.7))
                    }
                } else {
                    Text("予定なし")
                        .font(.system(size: 14))
                        .foregroundColor(.black.opacity(0.7))
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

    private func nextItem(afterSeconds seconds: Int) -> ScheduleItem? {
        let startMinutes = Int(ceil(Double(seconds) / 60.0))
        return viewModel.items
            .filter { $0.startMinutes >= startMinutes }
            .min(by: { $0.startMinutes < $1.startMinutes })
    }

    private func formatCountdown(seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }

    private func minutesToTime(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        return String(format: "%02d:%02d", h, m)
    }
}

private struct TimelineDropDelegate: DropDelegate {
    let hourHeight: CGFloat
    let minuteStep: Int
    let timelineHeight: CGFloat
    @Binding var preview: DropPreview?
    @Binding var previewDuration: Int?
    @Binding var dragDuration: Int?
    let onPreview: (Int, CGPoint) -> Void
    let onDrop: (Int, CGPoint) -> Void
    @State private var isLoadingDuration = false

    func dropEntered(info: DropInfo) {
        loadDurationIfNeeded(from: info)
    }

    func performDrop(info: DropInfo) -> Bool {
        defer {
            DispatchQueue.main.async {
                preview = nil
                previewDuration = nil
                dragDuration = nil
            }
        }

        guard let provider = info.itemProviders(for: [UTType.text]).first else { return false }

        provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { item, _ in
            guard let duration = parseDuration(from: item) else { return }

            DispatchQueue.main.async {
                let location = info.location
                onDrop(duration, location)
            }
        }
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        if let duration = previewDuration ?? dragDuration {
            onPreview(duration, info.location)
        } else {
            loadDurationIfNeeded(from: info)
        }
        return DropProposal(operation: .copy)
    }

    func dropExited(info: DropInfo) {
        preview = nil
        previewDuration = nil
    }

    private func loadDurationIfNeeded(from info: DropInfo) {
        guard !isLoadingDuration, previewDuration == nil,
              let provider = info.itemProviders(for: [UTType.text]).first
        else { return }

        isLoadingDuration = true
        provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { item, _ in
            defer { isLoadingDuration = false }
            guard let duration = parseDuration(from: item) else { return }

            DispatchQueue.main.async {
                previewDuration = duration
                onPreview(duration, info.location)
            }
        }
    }

    private func parseDuration(from item: NSSecureCoding?) -> Int? {
        if let data = item as? Data,
           let text = String(data: data, encoding: .utf8) {
            return Int(text.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        if let text = item as? String {
            return Int(text.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        if let text = item as? NSString {
            return Int(text.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return nil
    }
}

#Preview{
    ContentView()
}
#Preview("scheduleItemPreview"){
    ScheduleItemPreviewView(
        item: DropPreview(title: "Preview", startMinutes: 120, durationMinutes: 60)
    )
    .frame(height: 100)
    .padding(20)
}

#Preview("scheduleItem"){
    ScheduleItemView(
        item: ScheduleItem(title: "TEST", startMinutes: 90, durationMinutes: 60),
        isEditing: true,
        onEnterEdit: {},
        onMovePreview: { _ in },
        onMoveEnd: { _ in },
        onResizePreview: { _ in },
        onResizeEnd: { _ in },
        onDelete: {}
    )
    .padding(20)
}

#Preview("timeline with items") {
    TimelineScreen(items: [
        ScheduleItem(title: "Wake up", startMinutes: 2 * 60, durationMinutes: 15),
        ScheduleItem(title: "Workout", startMinutes: 2 * 60 + 45, durationMinutes: 60),
        ScheduleItem(title: "Breakfast", startMinutes: 4 * 60, durationMinutes: 30),
        ScheduleItem(title: "Study", startMinutes: 5 * 60, durationMinutes: 120)
    ])
}
