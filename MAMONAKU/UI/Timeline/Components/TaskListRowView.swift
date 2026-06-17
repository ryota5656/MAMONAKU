import SwiftUI

struct TaskListRowView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.editMode) private var editMode

    let item: TimelineItem
    let isOnTimeline: Bool
    @Binding var isDraggingTask: Bool
    @Binding var dragItemID: UUID?
    let onDelete: (UUID) -> Void
    let onEdit: () -> Void
    let heightForDuration: (Int) -> CGFloat

    var body: some View {
        Group {
            if isDragEnabled {
                rowContent
                    .onDrag {
                        isDraggingTask = true
                        dragItemID = item.id
                        return NSItemProvider(object: item.id.uuidString as NSString)
                    } preview: {
                        TaskDragPreview(item: item, height: heightForDuration(item.durationMinutes))
                    }
            } else {
                rowContent
            }
        }
    }

    private var isDragEnabled: Bool {
        !isOnTimeline && !(editMode?.wrappedValue.isEditing ?? false)
    }

    private var rowContent: some View {
        HStack {
            if isEditing && !isOnTimeline {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        onDelete(item.id)
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.red)
                }
                .buttonStyle(.borderless)
                .frame(width: 24, height: 24)
            } else if isEditing && isOnTimeline {
                Color.clear
                    .frame(width: 24, height: 24)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    PriorityIconView(priority: item.priority, color: priorityIconColor, size: 14)
                    Text(item.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary(palette: themeManager.theme, environmentScheme: colorScheme))
                }
                HStack(spacing: 6) {
                    Text("\(item.durationMinutes) min")
                        .font(.system(size: 12))
                        .foregroundStyle(durationColor)
                    if isOnTimeline, let dropDate = item.dropDate, let startMinutes = item.startMinutes {
                        Text("•")
                            .font(.system(size: 12))
                            .foregroundStyle(durationColor)
                        Text(scheduledDateText(dropDate: dropDate, startMinutes: startMinutes))
                            .font(.system(size: 12))
                            .foregroundStyle(durationColor)
                    }
                }
            }
            Spacer()
        }
        .opacity(isOnTimeline ? 0.5 : 1)
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isEditing else { return }
            onEdit()
        }
    }

    private var durationColor: Color {
        if isOnTimeline { return Color(uiColor: .tertiaryLabel) }
        return AppColors.textSecondary(palette: themeManager.theme, environmentScheme: colorScheme)
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

    private func scheduledDateText(dropDate: Date, startMinutes: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d"
        let dateStr = formatter.string(from: dropDate)
        let h = startMinutes / 60
        let m = startMinutes % 60
        return "\(dateStr) \(String(format: "%02d:%02d", h, m))"
    }

    private var isEditing: Bool {
        editMode?.wrappedValue.isEditing ?? false
    }
}

#Preview("TaskListRowView") {
    struct Container: View {
        @State var dragging = false
        @State var dragID: UUID? = nil
        @State var editMode: EditMode = .inactive

        var body: some View {
            List {
                TaskListRowView(
                    item: TimelineItem(title: "タスクA", durationMinutes: 30),
                    isOnTimeline: false,
                    isDraggingTask: $dragging,
                    dragItemID: $dragID,
                    onDelete: { _ in },
                    onEdit: {},
                    heightForDuration: { CGFloat($0) / 60 * 80 }
                )
            }
            .environment(\.editMode, $editMode)
            .environmentObject(ThemeManager())
        }
    }

    return Container()
}

