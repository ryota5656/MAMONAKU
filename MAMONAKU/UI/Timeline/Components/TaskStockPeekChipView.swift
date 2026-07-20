import SwiftUI

struct TaskStockPeekChipView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    let item: TimelineItem
    @Binding var isDraggingTask: Bool
    @Binding var dragItemID: UUID?
    let heightForDuration: (Int) -> CGFloat

    var body: some View {
        HStack(spacing: 5) {
            PriorityIconView(priority: item.priority, color: priorityIconColor, size: 12)
            Text(item.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColors.textPrimary(palette: themeManager.theme, environmentScheme: colorScheme))
                .lineLimit(1)
            Text("\(item.durationMinutes) min")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AppColors.textSecondary(palette: themeManager.theme, environmentScheme: colorScheme))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            Capsule(style: .continuous)
                .fill(AppColors.settingsListBackground(palette: themeManager.theme, environmentScheme: colorScheme))
        )
        .onDrag {
            isDraggingTask = true
            dragItemID = item.id
            return NSItemProvider(object: item.id.uuidString as NSString)
        } preview: {
            TaskDragPreview(item: item, height: heightForDuration(item.durationMinutes))
        }
    }

    private var priorityIconColor: Color {
        switch item.priority {
        case .low:
            return AppColors.textSecondary(palette: themeManager.theme, environmentScheme: colorScheme)
        case .medium:
            return AppColors.accent(palette: themeManager.theme, environmentScheme: colorScheme)
        case .high:
            return AppColors.strongAccent(palette: themeManager.theme, environmentScheme: colorScheme)
        }
    }
}

#Preview("TaskStockPeekChipView") {
    @Previewable @State var dragging = false
    @Previewable @State var dragID: UUID? = nil

    TaskStockPeekChipView(
        item: TimelineItem(title: "買い物", durationMinutes: 30),
        isDraggingTask: $dragging,
        dragItemID: $dragID,
        heightForDuration: { CGFloat($0) / 60 * 80 }
    )
    .padding()
    .environmentObject(ThemeManager())
}
