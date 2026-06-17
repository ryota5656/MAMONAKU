import SwiftUI

struct TaskListSheetHeaderBar: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    let hasTimelineTasks: Bool
    @Binding var showTimelineItems: Bool
    @Binding var editMode: EditMode
    @Binding var isSheetDraggable: Bool
    var onAddDebugTask: ((Int) -> Void)?

    var body: some View {
        let secondary = AppColors.textSecondary(palette: themeManager.theme, environmentScheme: colorScheme)
        let primary = AppColors.textPrimary(palette: themeManager.theme, environmentScheme: colorScheme)
        let accent = AppColors.strongAccent(palette: themeManager.theme, environmentScheme: colorScheme)

        HStack(spacing: 12) {
            Text("Stock")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(primary)
            Spacer()

            if hasTimelineTasks {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showTimelineItems.toggle()
                    }
                } label: {
                    Image(systemName: showTimelineItems ? "calendar.badge.clock" : "calendar")
                        .font(.system(size: 14))
                        .foregroundStyle(showTimelineItems ? accent : secondary)
                }
                .buttonStyle(.plain)
            }

            #if DEBUG
            if let onAddDebugTask {
                Menu {
                    Button("+1分テスト") { onAddDebugTask(1) }
                    Button("+2分テスト") { onAddDebugTask(2) }
                    Button("+3分テスト") { onAddDebugTask(3) }
                } label: {
                    Text("デバッグ追加")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(secondary)
                }
                .buttonStyle(.plain)
            }
            #endif

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    editMode = editMode.isEditing ? .inactive : .active
                    isSheetDraggable = !editMode.isEditing
                }
            } label: {
                Text(editMode.isEditing ? "完了" : "並び替え")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(accent)
            }
        }
        .padding(.top, 12)
    }
}

#Preview("TaskListSheetHeaderBar") {
    @Previewable @State var showTimelineItems = true
    @Previewable @State var editMode: EditMode = .inactive
    @Previewable @State var isSheetDraggable = true

    TaskListSheetHeaderBar(
        hasTimelineTasks: true,
        showTimelineItems: $showTimelineItems,
        editMode: $editMode,
        isSheetDraggable: $isSheetDraggable,
        onAddDebugTask: { _ in }
    )
    .padding()
    .background(Color(.systemBackground))
    .environmentObject(ThemeManager())
}

