import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct TimelineScreen: View {
    @StateObject private var viewModel = TimelineViewModel()
    @State private var sheetHeight: CGFloat = 0
    @State private var isHeaderExpanded = true
    @State private var isTaskSheetPresented = false
    @State private var isDraggingTask = false
    @State private var isSheetDropTargeted = false
    @State private var isTaskSheetDraggable = true
    @State private var taskSheetDetent: PresentationDetent = .fraction(0.45)
    @State private var headerHeight: CGFloat = 0
    @State private var isRadialMenuVisible = false
    @State private var radialSelection: RadialAction? = nil
    @State private var lastHapticSelection: RadialAction? = nil

    init() {
        _viewModel = StateObject(wrappedValue: TimelineViewModel())
    }

    init(items: [TimelineItem]) {
        _viewModel = StateObject(
            wrappedValue: TimelineViewModel(
                initialItems: items,
                enablePolling: false
            )
        )
    }

    var body: some View {
            ZStack(alignment: .top) {
                CountdownHeaderView(
                    items: viewModel.items,
                    isExpanded: $isHeaderExpanded
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .background(
                    GeometryReader { proxy in
                        Color.clear
                            .preference(key: HeaderHeightKey.self, value: proxy.size.height)
                    }
                )

                WhiteSheetView(
                    viewModel: viewModel,
                    sheetHeight: $sheetHeight
                )
                .offset(y: isHeaderExpanded ? (headerHeight + 12) : 0)
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isHeaderExpanded)

                }
                .sheet(isPresented: $isTaskSheetPresented) {
                    TaskListSheetView(
                        items: viewModel.items,
                        isPresented: $isTaskSheetPresented,
                        isDraggingTask: $isDraggingTask,
                        isSheetDropTargeted: $isSheetDropTargeted,
                        dragItemID: $viewModel.dragItemID,
                        isSheetExpanded: $viewModel.chipsExpanded,
                        isSheetDraggable: $isTaskSheetDraggable,
                        onMove: { from, to in
                            viewModel.moveTaskItems(from: from, to: to)
                        },
                        onAdd: { title, durationMinutes in
                            viewModel.addStockItem(title: title, durationMinutes: durationMinutes)
                        },
                        onDelete: { id in
                            viewModel.deleteItem(id: id)
                        }
                    )
                    .presentationDetents(
                        isTaskSheetDraggable ? [.fraction(0.45), .large] : [taskSheetDetent],
                        selection: $taskSheetDetent
                    )
                    .presentationDragIndicator(isTaskSheetDraggable ? .visible : .hidden)
                    .presentationBackgroundInteraction(.enabled)
                    .interactiveDismissDisabled(!isTaskSheetDraggable)
                }
                .onChange(of: viewModel.dropPreview) { _, preview in
                    guard isTaskSheetPresented, isDraggingTask, preview != nil else { return }
                    isDraggingTask = false
                    isTaskSheetPresented = false
                }
                .overlay(alignment: .bottomLeading) {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            isHeaderExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: isHeaderExpanded ? "chevron.down.circle.fill" : "chevron.up.circle.fill")
                            .font(.system(size: 35))
                            .foregroundStyle(Color.primary.opacity(0.8))
                            .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)
                    }
                    .padding(.leading, 30)
                    .padding(.bottom, 20)
                }
                .overlay(alignment: .bottomTrailing) {
                    ZStack {
                        if isRadialMenuVisible {
                            radialMenu
                        }

                        ZStack {
                            Circle()
                                .foregroundStyle(Color.primary.opacity(0.8))
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(Color.white)
                                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                        }
                        .frame(width: 35, height: 35)
                        .contentShape(Circle())
                        .onTapGesture {
                            isTaskSheetPresented = true
                        }
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    if !isRadialMenuVisible {
                                        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                                            isRadialMenuVisible = true
                                            radialSelection = nil
                                        }
                                    }
                                    let selection = radialAction(at: value.location, in: CGSize(width: 52, height: 52))
                                    radialSelection = selection
                                    if selection != nil, selection != lastHapticSelection {
                                        let generator = UIImpactFeedbackGenerator(style: .light)
                                        generator.prepare()
                                        generator.impactOccurred()
                                        lastHapticSelection = selection
                                    }
                                }
                                .onEnded { _ in
                                    if isRadialMenuVisible, let selection = radialSelection {
                                        trigger(action: selection)
                                    }
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                                        isRadialMenuVisible = false
                                        radialSelection = nil
                                        lastHapticSelection = nil
                                    }
                                }
                        )
                    }
                    .padding(.trailing, 30)
                    .padding(.bottom, 20)
            }
            .onPreferenceChange(HeaderHeightKey.self) { value in
                headerHeight = value
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
//            .background(
//                Color.clear
//                    .contentShape(Rectangle())
//                    .onTapGesture {
//                        if viewModel.editMode.isEditing {
//                            viewModel.editMode = .inactive
//                        }
//                    }
//            )
            .onAppear {
                viewModel.updateLiveActivity()
            }
            .onChange(of: viewModel.items) { _, _ in
                viewModel.updateLiveActivity()
            }
    }
}

private struct HeaderHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private enum RadialAction: CaseIterable {
    case actionA
    case actionB
    case actionC

    var icon: String {
        switch self {
        case .actionA: return "square.and.pencil"
        case .actionB: return "clock"
        case .actionC: return "flag"
        }
    }

    var offset: CGSize {
        switch self {
        case .actionA: return CGSize(width: -70, height: 0)
        case .actionB: return CGSize(width: 0, height: -70)
        case .actionC: return CGSize(width: -50, height: -50)
        }
    }
}

private extension TimelineScreen {
    var radialMenu: some View {
        ZStack {
            ForEach(RadialAction.allCases, id: \.self) { action in
                Circle()
                    .fill(radialSelection == action ? Color.black : Color.black.opacity(0.85))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: action.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                    )
                    .onTapGesture {
                        trigger(action: action)
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                            isRadialMenuVisible = false
                            radialSelection = nil
                        }
                    }
                    .offset(action.offset)
            }
        }
        .transition(.scale.combined(with: .opacity))
    }

    func radialAction(at location: CGPoint, in size: CGSize) -> RadialAction? {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let threshold: CGFloat = 22
        for action in RadialAction.allCases {
            let target = CGPoint(x: center.x + action.offset.width, y: center.y + action.offset.height)
            let dx = location.x - target.x
            let dy = location.y - target.y
            if sqrt(dx * dx + dy * dy) <= threshold {
                return action
            }
        }
        return nil
    }

    func trigger(action: RadialAction) {
        // Placeholder: implement specific actions later.
        switch action {
        case .actionA, .actionB, .actionC:
            break
        }
    }
}

#Preview{
    ContentView()
}
#Preview("scheduleItemPreview"){
    ScheduleItemPreviewView(
        item: TimelineItem(title: "Preview", durationMinutes: 60, startMinutes: 120),
        showTimeRange: true
    )
    .frame(height: 100)
    .padding(20)
}


#Preview("timeline with items") {
    TimelineScreen(items: [
        TimelineItem(title: "Wake up", durationMinutes: 15, startMinutes: 17 * 60, dropDate: Date()),
        TimelineItem(title: "Workout", durationMinutes: 60, startMinutes: 2 * 60 + 45, dropDate: Date()),
        TimelineItem(title: "Breakfast", durationMinutes: 30, startMinutes: 4 * 60, dropDate: Date()),
        TimelineItem(title: "Study", durationMinutes: 120, startMinutes: 5 * 60, dropDate: Date())
    ])
}
