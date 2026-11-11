import SwiftUI

/// タイムライン画面のエントリーポイント。ViewModel の保持と、ライフサイクル・シートの制御を担う。
struct TimelineScreen: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @State private var viewModel: TimelineViewModel

    init(viewModel: TimelineViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        TimelineScreenContent(state: viewModel.state, delegate: viewModel)
            .ignoresSafeArea(.keyboard)
            .onPreferenceChange(HeaderHeightKey.self) { height in
                viewModel.headerHeightDidChange(height)
            }
            .onAppear {
                viewModel.onAppear()
            }
            .sheet(item: presentedSheet) { sheet in
                sheetContent(for: sheet)
            }
    }

    private var presentedSheet: Binding<TimelineSheet?> {
        Binding(
            get: { viewModel.state.sheet },
            set: { sheet in
                if sheet == nil { viewModel.dismissSheet() }
            }
        )
    }

    @ViewBuilder
    private func sheetContent(for sheet: TimelineSheet) -> some View {
        let isSubscribed = subscriptionManager.effectiveIsSubscribed

        switch sheet {
        case .createTask:
            TaskCreateSheetView(
                isSubscribed: isSubscribed,
                onCancel: { viewModel.dismissSheet() },
                onCreate: { title, durationMinutes, priority, startDate, endDate, repeatRule in
                    viewModel.createTask(
                        title: title,
                        durationMinutes: durationMinutes,
                        priority: priority,
                        startDate: startDate,
                        endDate: endDate,
                        repeatRule: repeatRule
                    )
                }
            )
        case .editTask(let item):
            TaskEditSheetView(
                item: item,
                isSubscribed: isSubscribed,
                onCancel: { viewModel.dismissSheet() },
                onSave: { title, durationMinutes, priority in
                    viewModel.updateTask(
                        id: item.id,
                        title: title,
                        durationMinutes: durationMinutes,
                        priority: priority
                    )
                },
                onDelete: { viewModel.deleteTask(id: item.id) }
            )
        case .datePicker:
            TimelineDatePickerSheet(
                selectedDate: viewModel.state.selectedDate,
                onSelectDate: { viewModel.timelineDidSelectDate($0) },
                onClose: { viewModel.dismissSheet() }
            )
        case .routines:
            RoutineListSheetView(
                routines: viewModel.state.routines,
                items: viewModel.state.items,
                isSubscribed: isSubscribed,
                onUpdate: { id, title, priority, startDate, endDate, repeatRule in
                    viewModel.updateRoutine(
                        id: id,
                        title: title,
                        priority: priority,
                        startDate: startDate,
                        endDate: endDate,
                        repeatRule: repeatRule
                    )
                },
                onDelete: { viewModel.deleteRoutine(id: $0) },
                onClose: { viewModel.dismissSheet() }
            )
        }
    }
}
