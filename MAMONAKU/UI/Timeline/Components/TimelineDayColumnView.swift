import SwiftUI
import UniformTypeIdentifiers

struct TimelineDayColumnView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @ObservedObject var viewModel: TimelineViewModel

    let date: Date
    let width: CGFloat
    let height: CGFloat
    let currentTimeAnchorID: String

    var body: some View {
        let items = viewModel.items(for: date)
        let itemWidth = max(80, width - (viewModel.timelinePadding * 0.5))
        let showTimeThreshold: CGFloat = 30

        ZStack(alignment: .topLeading) {
            TimelineGridView(
                width: width,
                height: height,
                hourHeight: viewModel.hourHeight,
                zoomScale: viewModel.zoomScale,
                gridFill: AppColors.background(palette: themeManager.theme, environmentScheme: colorScheme),
                gridLine: AppColors.gridLine(palette: themeManager.theme, environmentScheme: colorScheme)
            )

            Rectangle()
                .fill(AppColors.gridLine(palette: themeManager.theme, environmentScheme: colorScheme))
                .frame(width: 1, height: height)
                .offset(x: 7)
                .allowsHitTesting(false)

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
                        isEditing: viewModel.editingItemID == item.id,
                        showTimeRange: showTimeRange,
                        onEnterEdit: {
                            if viewModel.editMode.isEditing && viewModel.editingItemID == item.id {
                                viewModel.exitEditMode()
                            } else {
                                viewModel.requestEnterEditMode(for: item.id)
                            }
                        },
                        onTitleCommit: { title in
                            viewModel.updateItemTitle(id: item.id, title: title)
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
                                viewModel.editingItemID = $0
                                viewModel.editMode = .active
                            }
                        },
                        onComplete: nil,
                        onUncomplete: nil
                    )
                    .padding(.trailing, 7)
                    .frame(width: .infinity, height: itemHeight)
                    .offset(x: 0, y: viewModel.yOffset(for: startMinutes))
                }
            }

            if let preview = viewModel.dropPreview, isSameDay(preview.dropDate, date) {
                let previewHeight = viewModel.heightForDuration(preview.durationMinutes)
                ScheduleItemPreviewView(item: preview, showTimeRange: true)
                    .padding(.trailing, 7)
                    .frame(width: .infinity, height: previewHeight)
                    .offset(x: 0, y: viewModel.yOffset(for: preview.startMinutes ?? 0))
                    .zIndex(0)
                    .allowsHitTesting(false)
            }

            if let preview = viewModel.resizePreview, isSameDay(preview.dropDate, date) {
                let previewHeight = viewModel.heightForDuration(preview.durationMinutes)
                ScheduleItemPreviewView(item: preview, showTimeRange: true)
                    .frame(width: itemWidth, height: previewHeight)
                    .offset(x: 0, y: viewModel.yOffset(for: preview.startMinutes ?? 0))
                    .zIndex(0)
                    .allowsHitTesting(false)
            }

            if let pending = viewModel.pendingPlacement, Calendar.current.isDate(pending.date, inSameDayAs: date) {
                PendingPlacementCardView(
                    onSubmit: { title in viewModel.commitPendingPlacement(title: title) },
                    onCancel: { viewModel.cancelPendingPlacement() }
                )
                .frame(width: itemWidth, height: viewModel.heightForDuration(30))
                .offset(x: 0, y: viewModel.yOffset(for: pending.startMinutes))
                .zIndex(10)
            }

            if Calendar.current.isDate(date, inSameDayAs: Date()) {
                let anchorY = min(
                    max(0, viewModel.yOffset(for: viewModel.minutesSinceMidnight(date: Date()))),
                    max(0, height - 1)
                )
                VStack(spacing: 0) {
                    Color.clear.frame(height: anchorY)
                    Color.clear
                        .frame(width: 1, height: 1)
                        .id(currentTimeAnchorID)
                    Spacer(minLength: 0)
                }
                .frame(width: 1, height: height, alignment: .top)
                .allowsHitTesting(false)

                TimelineCurrentTimeLineView(
                    width: width,
                    yOffset: { viewModel.yOffset(for: $0) },
                    minutesSinceMidnight: { viewModel.minutesSinceMidnight(date: $0) },
                    currentTimeText: { viewModel.currentTimeText(date: $0) },
                    accent: AppColors.strongAccent(palette: themeManager.theme, environmentScheme: colorScheme),
                    insideText: AppColors.strongAccentInsideText(palette: themeManager.theme, environmentScheme: colorScheme)
                )
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

    private func isSameDay(_ lhs: Date?, _ rhs: Date) -> Bool {
        guard let lhs else { return false }
        return Calendar.current.isDate(lhs, inSameDayAs: rhs)
    }
}

#Preview("TimelineDayColumnView") {
    let items = [
        TimelineItem(title: "Wake up", durationMinutes: 30, startMinutes: 9 * 60, dropDate: Date()),
        TimelineItem(title: "Workout", durationMinutes: 60, startMinutes: 10 * 60, dropDate: Date())
    ]
    let vm = TimelineViewModel(initialItems: items, enablePolling: false)
    return TimelineDayColumnView(
        viewModel: vm,
        date: Calendar.current.startOfDay(for: Date()),
        width: 260,
        height: 80 * 24,
        currentTimeAnchorID: "currentTimeAnchor"
    )
    .environmentObject(ThemeManager())
    .padding()
}

