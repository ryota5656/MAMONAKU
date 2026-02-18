import SwiftUI
import UniformTypeIdentifiers

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
                    Button {
                        isTaskSheetPresented = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 35, weight: .bold))
                            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
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
