import SwiftUI

struct TaskEditSheetView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    let item: TimelineItem
    let isSubscribed: Bool
    let onCancel: () -> Void
    let onSave: (String, Int, TaskPriority) -> Void
    let onDelete: () -> Void
    @State private var title: String
    @State private var durationMinutes: Int
    @State private var priority: TaskPriority
    @State private var isDeleteConfirmationPresented = false

    init(
        item: TimelineItem,
        isSubscribed: Bool,
        onCancel: @escaping () -> Void,
        onSave: @escaping (String, Int, TaskPriority) -> Void,
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

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("タスク") {
                    TextField("タイトル", text: $title)
                        .submitLabel(.done)

                    Picker("時間", selection: $durationMinutes) {
                        ForEach(Array(stride(from: 5, through: 480, by: 5)), id: \.self) { minutes in
                            Text("\(minutes) min")
                                .tag(minutes)
                        }
                    }

                    if isSubscribed {
                        Picker("優先度", selection: $priority) {
                            ForEach(TaskPriority.allCases, id: \.rawValue) { priority in
                                Label(priority.displayName, systemImage: priority.iconName)
                                    .tag(priority)
                            }
                        }
                    } else {
                        HStack {
                            Text("優先度")
                            Spacer()
                            Label(TaskPriority.low.displayName, systemImage: TaskPriority.low.iconName)
                                .foregroundStyle(AppColors.textSecondary(palette: themeManager.theme, environmentScheme: colorScheme))
                        }
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
                        onSave(
                            title.trimmingCharacters(in: .whitespacesAndNewlines),
                            durationMinutes,
                            isSubscribed ? priority : .low
                        )
                    }
                    .disabled(!canSave)
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

#Preview("TaskEditSheetView - subscribed") {
    TaskEditSheetView(
        item: TimelineItem(title: "編集テスト", durationMinutes: 30, startMinutes: nil, dropDate: nil, priority: .high),
        isSubscribed: true,
        onCancel: {},
        onSave: { _, _, _ in },
        onDelete: {}
    )
    .environmentObject(ThemeManager())
}

#Preview("TaskEditSheetView - free") {
    TaskEditSheetView(
        item: TimelineItem(title: "編集テスト", durationMinutes: 30, startMinutes: nil, dropDate: nil, priority: .high),
        isSubscribed: false,
        onCancel: {},
        onSave: { _, _, _ in },
        onDelete: {}
    )
    .environmentObject(ThemeManager())
}
