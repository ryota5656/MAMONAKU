import SwiftUI
import UniformTypeIdentifiers

enum TaskStockPeekChipInteractionStyle {
    /// SwiftUI の onDrag / onDrop を使う（従来の ScrollView 用）
    case dragAndDrop
    /// 見た目のみ。DnD は UICollectionView 側で扱う
    case displayOnly
}

struct TaskStockPeekChipView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    let item: TimelineItem
    @Binding var isDraggingTask: Bool
    @Binding var dragItemID: UUID?
    let heightForDuration: (Int) -> CGFloat
    var onTap: (() -> Void)? = nil
    var onReorderDrop: ((UUID) -> Void)? = nil
    var interactionStyle: TaskStockPeekChipInteractionStyle = .dragAndDrop

    var body: some View {
        let primary = AppColors.textPrimary(palette: themeManager.theme, environmentScheme: colorScheme)
        let secondary = AppColors.textSecondary(palette: themeManager.theme, environmentScheme: colorScheme)

        chipContent(primary: primary, secondary: secondary)
            .modifier(ChipInteractionModifier(
                style: interactionStyle,
                item: item,
                isDraggingTask: $isDraggingTask,
                dragItemID: $dragItemID,
                heightForDuration: heightForDuration,
                onTap: onTap,
                onReorderDrop: onReorderDrop
            ))
    }

    private func chipContent(primary: Color, secondary: Color) -> some View {
        HStack(spacing: 6) {
            PriorityIconView(priority: item.priority, color: priorityIconColor, size: 13)

            Text(item.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(primary)
                .lineLimit(1)

            Text("\(item.durationMinutes)m")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    Capsule(style: .continuous)
                        .fill(durationBadgeFill)
                )
        }
        .padding(.leading, 11)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .background {
            Capsule(style: .continuous)
                .fill(chipFill)
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(priorityBorderColor, lineWidth: 1)
                }
                .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 1)
        }
        .contentShape(Capsule())
    }

    /// Liquid Glass 上でも沈まない、明るいフロスト面
    private var chipFill: LinearGradient {
        let topOpacity: Double = colorScheme == .dark ? 0.28 : 0.92
        let bottomOpacity: Double = colorScheme == .dark ? 0.16 : 0.72
        return LinearGradient(
            colors: [
                Color.white.opacity(topOpacity),
                Color.white.opacity(bottomOpacity)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var durationBadgeFill: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.14)
            : Color.black.opacity(0.05)
    }

    private var priorityBorderColor: Color {
        priorityIconColor.opacity(colorScheme == .dark ? 0.35 : 0.28)
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

private struct ChipInteractionModifier: ViewModifier {
    let style: TaskStockPeekChipInteractionStyle
    let item: TimelineItem
    @Binding var isDraggingTask: Bool
    @Binding var dragItemID: UUID?
    let heightForDuration: (Int) -> CGFloat
    var onTap: (() -> Void)?
    var onReorderDrop: ((UUID) -> Void)?

    func body(content: Content) -> some View {
        switch style {
        case .displayOnly:
            content
        case .dragAndDrop:
            content
                .onTapGesture {
                    onTap?()
                }
                .onDrag {
                    isDraggingTask = true
                    dragItemID = item.id
                    return NSItemProvider(object: item.id.uuidString as NSString)
                } preview: {
                    TaskDragPreview(item: item, height: heightForDuration(item.durationMinutes))
                }
                .onDrop(of: [UTType.text], isTargeted: nil) { providers in
                    guard let onReorderDrop else { return false }
                    guard let provider = providers.first else { return false }
                    _ = provider.loadObject(ofClass: NSString.self) { object, _ in
                        guard let raw = object as? String,
                              let id = UUID(uuidString: raw.trimmingCharacters(in: .whitespacesAndNewlines))
                        else { return }
                        DispatchQueue.main.async {
                            onReorderDrop(id)
                        }
                    }
                    return true
                }
        }
    }
}

#Preview("TaskStockPeekChipView") {
    @Previewable @State var dragging = false
    @Previewable @State var dragID: UUID? = nil

    ZStack {
        LinearGradient(
            colors: [Color.blue.opacity(0.4), Color.teal.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        HStack(spacing: 8) {
            TaskStockPeekChipView(
                item: TimelineItem(title: "買い物", durationMinutes: 30),
                isDraggingTask: $dragging,
                dragItemID: $dragID,
                heightForDuration: { CGFloat($0) / 60 * 80 }
            )
            TaskStockPeekChipView(
                item: TimelineItem(title: "読書", durationMinutes: 45, priority: .high),
                isDraggingTask: $dragging,
                dragItemID: $dragID,
                heightForDuration: { CGFloat($0) / 60 * 80 }
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }
    .environmentObject(ThemeManager())
}
