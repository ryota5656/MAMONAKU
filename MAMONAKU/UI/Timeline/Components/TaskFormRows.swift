import SwiftUI

/// タスクの所要時間を 5 分刻みで選ぶ行（作成・編集シート共通）。
struct TaskDurationPickerRow: View {
    @Binding var durationMinutes: Int

    var body: some View {
        Picker("時間", selection: $durationMinutes) {
            ForEach(Array(stride(from: 5, through: 480, by: 5)), id: \.self) { minutes in
                Text("\(minutes) min")
                    .tag(minutes)
            }
        }
    }
}

/// タスクの優先度を選ぶ行（作成・編集シート共通）。
/// PLUS 未加入の場合は選択できず、Low 固定で表示する。
struct TaskPriorityRow: View {
    @Environment(\.appTheme) private var theme
    @Binding var priority: TaskPriority
    let isSubscribed: Bool

    var body: some View {
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
                    .foregroundStyle(theme.textSecondary)
            }
        }
    }
}

#Preview("TaskFormRows") {
    @Previewable @State var durationMinutes = 30
    @Previewable @State var priority = TaskPriority.medium
    Form {
        TaskDurationPickerRow(durationMinutes: $durationMinutes)
        TaskPriorityRow(priority: $priority, isSubscribed: true)
        TaskPriorityRow(priority: $priority, isSubscribed: false)
    }
}
