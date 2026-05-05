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
                                        allDayTagRow(items: allDayItems)
                                    }

                                    HStack(alignment: .top, spacing: 0) {
                                        timeColumn
                                        singleDayTimelineColumn(date: date)
                                    }
                                    .background(
                                        Color.clear
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                if viewModel.editMode.isEditing {
                                                    viewModel.exitEditMode()
                                                }
                                            }
                                    )
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
        let rowHeight = viewModel.hourHeight * viewModel.zoomScale
        return VStack(spacing: 0) {
            ForEach(0...24, id: \.self) { hour in
                Text(String(format: "%02d:00", hour))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(AppColors.textSecondary(palette: themeManager.theme, environmentScheme: colorScheme))
                    .frame(
                        width: viewModel.timeColumnWidth,
                        height: rowHeight,
                        alignment: .topLeading
                    )
            }
        }
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

    private func singleDayTimelineColumn(date: Date) -> some View {
        let height = viewModel.hourHeight * viewModel.zoomScale * 24
        return GeometryReader { geo in
            dayTimelineColumn(date: date, width: geo.size.width, height: height)
        }
        .frame(height: viewModel.hourHeight * viewModel.zoomScale * 24)
    }

    private func dayTimelineColumn(date: Date, width: CGFloat, height: CGFloat) -> some View {
        let items = viewModel.items(for: date)
        let itemWidth = max(80, width - (viewModel.timelinePadding * 0.5))
        let showTimeThreshold: CGFloat = 30

        return ZStack(alignment: .topLeading) {
            timelineGrid(width: width, height: height)
            
            // グリッドの縦ライン
            Rectangle()
                .fill(AppColors.gridLine(palette: themeManager.theme, environmentScheme: colorScheme))
                .frame(width: 1, height: height)
                .offset(x: 7)
                .allowsHitTesting(false)

            // 背面のタップ層（空き領域タップで編集モード解除 or 仮配置取り消し）
            Color.primary.opacity(0.001)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    if viewModel.pendingPlacement != nil {
                        viewModel.cancelPendingPlacement()
                    } else if viewModel.editMode.isEditing {
                        viewModel.exitEditMode()
                    }
                }

            // 長押しでその位置に30分の仮アイテムを開始（編集モード中は無効・タップを背面層に通して編集解除）
            LongPressLocationView { y in
                viewModel.startPendingPlacement(date: date, y: y)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(viewModel.pendingPlacement == nil && !viewModel.editMode.isEditing)

            ForEach(items) { item in
                if let startMinutes = item.startMinutes {
                    let itemHeight = viewModel.heightForDuration(item.durationMinutes)
                    let showTimeRange = itemHeight > showTimeThreshold
                    ScheduleItemView(
                        item: item,
                        isEditing: viewModel.editMode.isEditing,
                        showTimeRange: showTimeRange,
                        onEnterEdit: {
                            if viewModel.editMode.isEditing {
                                viewModel.exitEditMode()
                            } else {
                                viewModel.requestEnterEditMode()
                            }
                        },
                        onResizePreview: { deltaY in
                            viewModel.updateResizePreview(item: item, deltaY: deltaY)
                        },
                        onResizeEnd: { deltaY in
                            viewModel.commitResize(item: item, deltaY: deltaY)
                        },
                        onDragStart: {
                            viewModel.dragItemID = $0
                            if !viewModel.isInEditModeExitCooldown() {
                                viewModel.editMode = .active
                            }
                        },
                        onComplete: nil,
                        onUncomplete: nil
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
                    showTimeRange: previewHeight > showTimeThreshold
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
                    showTimeRange: previewHeight > showTimeThreshold
                )
                .frame(
                    width: itemWidth,
                    height: previewHeight
                )
                .offset(x: 0, y: viewModel.yOffset(for: preview.startMinutes ?? 0))
                .zIndex(0)
                .allowsHitTesting(false)
            }

            if let pending = viewModel.pendingPlacement, Calendar.current.isDate(pending.date, inSameDayAs: date) {
                PendingPlacementCardView(
                    onSubmit: { title in
                        viewModel.commitPendingPlacement(title: title)
                    },
                    onCancel: {
                        viewModel.cancelPendingPlacement()
                    }
                )
                .frame(width: itemWidth, height: viewModel.heightForDuration(30))
                .offset(x: 0, y: viewModel.yOffset(for: pending.startMinutes))
                .zIndex(10)
            }

            if Calendar.current.isDate(date, inSameDayAs: Date()) {
                let anchorY = min(max(0, viewModel.yOffset(for: viewModel.minutesSinceMidnight(date: Date()))), max(0, height - 1))
                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: anchorY)
                    Color.clear
                        .frame(width: 1, height: 1)
                        .id(currentTimeAnchorID)
                    Spacer(minLength: 0)
                }
                .frame(width: 1, height: height, alignment: .top)
                .allowsHitTesting(false)
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
                    if item.dropDate != nil {
                        viewModel.moveItemTo(item: item, dropY: location.y, on: date)
                    } else {
                        viewModel.addItem(item: item, dropY: location.y, on: date)
                    }
                }
            )
        )
    }

    private func allDayTagRow(items: [TimelineItem]) -> some View {
        let textColor = AppColors.textPrimary(palette: themeManager.theme, environmentScheme: colorScheme)
        let chipBackground = AppColors.settingsListBackground(palette: themeManager.theme, environmentScheme: colorScheme)

        return HStack(alignment: .center, spacing: 0) {
            Color.clear
                .frame(width: viewModel.timeColumnWidth)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(items) { item in
                        Text(item.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(textColor)
                            .lineLimit(1)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(chipBackground)
                            )
                    }
                }
            }
        }
    }

    // MARK: - 現在時間の位置ライン
    private func currentTimeLine(width: CGFloat) -> some View {
        TimelineView(.animation) { context in
            let minutes = viewModel.minutesSinceMidnight(date: context.date)
            let y = viewModel.yOffset(for: minutes)

            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(AppColors.strongAccent(palette: themeManager.theme, environmentScheme: colorScheme))
                    .frame(width: width, height: 2)
                    .offset(y: -10)
                Text(viewModel.currentTimeText(date: context.date))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(AppColors.strongAccentInsideText(palette: themeManager.theme, environmentScheme: colorScheme))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppColors.strongAccent(palette: themeManager.theme, environmentScheme: colorScheme))
                    .cornerRadius(4)
                    .offset(x: 4, y: -20)
            }
            .offset(y: y)
        }
    }

    private func timelineGrid(width: CGFloat, height: CGFloat) -> some View {
        let gridFill = AppColors.background(palette: themeManager.theme, environmentScheme: colorScheme)
        let gridLine = AppColors.gridLine(palette: themeManager.theme, environmentScheme: colorScheme)
        return ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(gridFill)
                .frame(width: width, height: height)

            ForEach(0...24, id: \.self) { hour in
                Rectangle()
                    .fill(gridLine)
                    .frame(width: 10, height: 1)
                    .offset(y: CGFloat(hour) * viewModel.hourHeight * viewModel.zoomScale)
            }
        }
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

// MARK: - 長押しで位置（Y）を取得（スクロールと併用できるよう UIKit で取得）
private struct LongPressLocationView: UIViewRepresentable {
    var onLongPress: (CGFloat) -> Void

    func makeUIView(context: Context) -> UIView {
        let v = UIView()
        v.backgroundColor = .clear
        let longPress = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.didLongPress(_:)))
        longPress.minimumPressDuration = 0.5
        longPress.delaysTouchesBegan = false
        v.addGestureRecognizer(longPress)
        return v
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onLongPress = onLongPress
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onLongPress: onLongPress)
    }

    class Coordinator: NSObject {
        var onLongPress: (CGFloat) -> Void

        init(onLongPress: @escaping (CGFloat) -> Void) {
            self.onLongPress = onLongPress
        }

        @objc func didLongPress(_ g: UILongPressGestureRecognizer) {
            guard g.state == .began else { return }
            let y = g.location(in: g.view).y
            onLongPress(y)
        }
    }
}

// MARK: - 仮配置カード（タイトル入力、Enter で確定）
private struct PendingPlacementCardView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var title: String = ""
    @FocusState private var isFocused: Bool
    var onSubmit: (String) -> Void
    var onCancel: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            TextField("タイトルを入力", text: $title)
                .textFieldStyle(.plain)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppColors.textPrimary(palette: themeManager.theme, environmentScheme: colorScheme))
                .padding(.horizontal, 20)
                .padding(.vertical, 6)
                .submitLabel(.done)
                .onSubmit {
                    onSubmit(title)
                }
                .focused($isFocused)
                .onAppear { isFocused = true }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppColors.settingsListBackground(palette: themeManager.theme, environmentScheme: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppColors.gridLine(palette: themeManager.theme, environmentScheme: colorScheme), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
        )
    }
}

#Preview("timeline with items") {
    TimelineScreen(items: [
        TimelineItem(title: "Wake up", durationMinutes: 15, startMinutes: 11 * 60, dropDate: Date()),
        TimelineItem(title: "Workout", durationMinutes: 60, startMinutes: 3 * 60, dropDate: Date()),
        TimelineItem(title: "Breakfast", durationMinutes: 15, startMinutes: 4 * 60, dropDate: Date()),
        TimelineItem(title: "Study", durationMinutes: 120, startMinutes: 5 * 60, dropDate: Date())
    ])
    .environmentObject(SubscriptionManager())
    .environmentObject(ThemeManager())
}
