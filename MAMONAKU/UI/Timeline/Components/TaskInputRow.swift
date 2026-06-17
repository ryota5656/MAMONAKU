import SwiftUI

struct TaskInputRow: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    let isSubscribed: Bool
    @Binding var title: String
    @Binding var durationMinutes: Int
    @Binding var priority: TaskPriority
    var isTaskInputFocused: FocusState<Bool>.Binding
    let onSubmit: (String, Int, TaskPriority) -> Void

    var body: some View {
        HStack(spacing: 8) {
            if isSubscribed {
                Menu {
                    Picker("優先度", selection: $priority) {
                        ForEach(TaskPriority.allCases, id: \.rawValue) { p in
                            Label(p.displayName, systemImage: p.iconName)
                                .tag(p)
                        }
                    }
                    .pickerStyle(.inline)
                } label: {
                    PriorityIconView(
                        priority: priority,
                        color: priorityColor(for: priority),
                        size: 22
                    )
                }
            } else {
                PriorityIconView(
                    priority: .low,
                    color: priorityColor(for: .low),
                    size: 22
                )
            }

            TextField("タスクを追加", text: $title)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
                .submitLabel(.next)
                .focused(isTaskInputFocused)
                .onSubmit {
                    submitIfPossible()
                }

            TaskDurationMenu(minutes: $durationMinutes)

            Button {
                submitIfPossible()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(canAdd ? Color.accentColor : Color.secondary)
            }
            .disabled(!canAdd)
        }
    }

    private var canAdd: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submitIfPossible() {
        guard canAdd else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let p = isSubscribed ? priority : TaskPriority.low
        onSubmit(trimmed, durationMinutes, p)
        title = ""
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isTaskInputFocused.wrappedValue = true
        }
    }

    private func priorityColor(for p: TaskPriority) -> Color {
        switch p {
        case .low:
            return AppColors.textSecondary(palette: themeManager.theme, environmentScheme: colorScheme)
        case .medium:
            return AppColors.accent(palette: themeManager.theme, environmentScheme: colorScheme)
        case .high:
            return AppColors.strongAccent(palette: themeManager.theme, environmentScheme: colorScheme)
        }
    }
}

#Preview("TaskInputRow - subscribed") {
    struct Container: View {
        @State var title = "タスク"
        @State var duration = 30
        @State var priority: TaskPriority = .medium
        @FocusState var focused: Bool

        var body: some View {
            TaskInputRow(
                isSubscribed: true,
                title: $title,
                durationMinutes: $duration,
                priority: $priority,
                isTaskInputFocused: $focused,
                onSubmit: { _, _, _ in }
            )
            .padding()
            .environmentObject(ThemeManager())
        }
    }

    return Container()
}

