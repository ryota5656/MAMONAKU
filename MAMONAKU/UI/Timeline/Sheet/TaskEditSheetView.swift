import SwiftUI

/// タスク編集シート（タイトル・所要時間・優先度の変更と削除）。
struct TaskEditSheetView: View {
    let item: TimelineItem
    let isSubscribed: Bool
    let onCancel: () -> Void
    let onSave: (_ title: String, _ durationMinutes: Int, _ priority: TaskPriority) -> Void
    let onDelete: () -> Void

    @State private var title: String
    @State private var durationMinutes: Int
    @State private var priority: TaskPriority
    @State private var isDeleteConfirmationPresented = false

    init(
        item: TimelineItem,
        isSubscribed: Bool,
        onCancel: @escaping () -> Void,
        onSave: @escaping (_ title: String, _ durationMinutes: Int, _ priority: TaskPriority) -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.item = item
        self.isSubscribed = isSubscribed
        self.onCancel = onCancel
        self.onSave = onSave
        self.onDelete = onDelete
        _title = State(initialValue: item.title)
        _durationMinutes = State(initialValue: item.durationMinutes)
        _priority = State(initialValue: isSubscribed ? item.priority : .low)
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("タイトル", text: $title)
                        .submitLabel(.done)
                    TaskDurationPickerRow(durationMinutes: $durationMinutes)
                    TaskPriorityRow(priority: $priority, isSubscribed: isSubscribed)
                } header: {
                    Text("タスク")
                } footer: {
                    if item.routineID != nil {
                        Text("時間を変えて保存すると、この日だけルーティンから外れます。")
                    }
                }
            }
            .navigationTitle("タスクを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル", action: onCancel)
                }
                ToolbarItemGroup(placement: .confirmationAction) {
                    Button("削除", role: .destructive) {
                        isDeleteConfirmationPresented = true
                    }
                    Button("保存") {
                        onSave(trimmedTitle, durationMinutes, isSubscribed ? priority : .low)
                    }
                    .disabled(trimmedTitle.isEmpty)
                }
            }
            .alert("タスクを削除", isPresented: $isDeleteConfirmationPresented) {
                Button("削除", role: .destructive, action: onDelete)
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("「\(item.title)」を削除しますか？この操作は取り消せません。")
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview("PLUS 加入中") {
    TaskEditSheetView(
        item: TimelineItem(title: "編集テスト", durationMinutes: 30, priority: .high),
        isSubscribed: true,
        onCancel: {},
        onSave: { _, _, _ in },
        onDelete: {}
    )
}

#Preview("未加入") {
    TaskEditSheetView(
        item: TimelineItem(title: "編集テスト", durationMinutes: 30, priority: .high),
        isSubscribed: false,
        onCancel: {},
        onSave: { _, _, _ in },
        onDelete: {}
    )
}
