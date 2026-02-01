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
                    CountdownHeaderView(items: viewModel.items)
                }
                .padding(.top, 24)
                .frame(maxWidth: .infinity, alignment: .leading)

                WhiteSheetView(
                    viewModel: viewModel,
                    sheetHeight: $sheetHeight
                )
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
        TimelineItem(title: "Wake up", durationMinutes: 15, startMinutes: 2 * 60, dropDate: Date()),
        TimelineItem(title: "Workout", durationMinutes: 60, startMinutes: 2 * 60 + 45, dropDate: Date()),
        TimelineItem(title: "Breakfast", durationMinutes: 30, startMinutes: 4 * 60, dropDate: Date()),
        TimelineItem(title: "Study", durationMinutes: 120, startMinutes: 5 * 60, dropDate: Date())
    ])
}
