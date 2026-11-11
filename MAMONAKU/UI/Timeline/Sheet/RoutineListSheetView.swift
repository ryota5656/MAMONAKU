import SwiftUI

/// 登録済みルーティンの一覧。行を開くと編集でき、削除するとまだ紐づいている予定をまとめて消す。
struct RoutineListSheetView: View {
    @Environment(\.appTheme) private var theme

    let routines: [TimelineRoutine]
    let items: [TimelineItem]
    let isSubscribed: Bool
    let onUpdate: (
        _ id: UUID,
        _ title: String,
        _ priority: TaskPriority,
        _ startDate: Date,
        _ endDate: Date,
        _ repeatRule: RoutineRepeat
    ) -> Bool
    let onDelete: (UUID) -> Void
    let onClose: () -> Void

    @State private var editingRoutine: TimelineRoutine?
    @State private var pendingDelete: TimelineRoutine?

    private var visibleRoutines: [TimelineRoutine] {
        routines.filter { remainingCount(of: $0.id) > 0 }
    }

    var body: some View {
        NavigationStack {
            Group {
                if visibleRoutines.isEmpty {
                    ContentUnavailableView(
                        "ルーティンはありません",
                        systemImage: "repeat",
                        description: Text("タスク作成で日時を指定し、「繰り返す」をオンにすると、ここにまとまります。")
                    )
                } else {
                    List {
                        ForEach(visibleRoutines) { routine in
                            Button {
                                editingRoutine = routine
                            } label: {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(routine.title)
                                            .font(.body.weight(.semibold))
                                            .foregroundStyle(theme.textPrimary)
                                        Text(routine.scheduleSummary())
                                            .font(.subheadline)
                                            .foregroundStyle(theme.textSecondary)
                                        Text("\(remainingCount(of: routine.id))件")
                                            .font(.caption)
                                            .foregroundStyle(theme.textSecondary)
                                    }
                                    Spacer(minLength: 8)
                                    Image(systemName: "chevron.right")
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(theme.textSecondary)
                                }
                                .padding(.vertical, 4)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("編集")
                            .swipeActions {
                                Button("削除", role: .destructive) {
                                    pendingDelete = routine
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("ルーティン")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $editingRoutine) { routine in
                RoutineEditSheetView(
                    routine: routine,
                    isSubscribed: isSubscribed,
                    onCancel: { editingRoutine = nil },
                    onSave: { title, priority, startDate, endDate, repeatRule in
                        let didSave = onUpdate(routine.id, title, priority, startDate, endDate, repeatRule)
                        if didSave {
                            editingRoutine = nil
                        }
                        return didSave
                    }
                )
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる", action: onClose)
                }
            }
            .alert(
                "ルーティンを削除",
                isPresented: Binding(
                    get: { pendingDelete != nil },
                    set: { if !$0 { pendingDelete = nil } }
                )
            ) {
                Button("削除", role: .destructive) {
                    if let pendingDelete {
                        onDelete(pendingDelete.id)
                    }
                    pendingDelete = nil
                }
                Button("キャンセル", role: .cancel) {
                    pendingDelete = nil
                }
            } message: {
                Text("「\(pendingDelete?.title ?? "")」の、まだこのルーティンに属している予定をまとめて削除します。時刻を変えて外した日は残ります。")
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func remainingCount(of routineID: UUID) -> Int {
        items.filter { $0.routineID == routineID }.count
    }
}
