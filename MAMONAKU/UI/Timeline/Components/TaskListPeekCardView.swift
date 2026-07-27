import SwiftUI
import UIKit

/// ピーク時にタイムライン上へ浮かせて表示する Stock カード（シート外）
/// タイムライン上のアイテムをここにドロップするとタスクリストへ戻す。
/// TabView の Liquid Glass タブバーに合わせた半透明ガラス表現。
struct TaskListPeekCardView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    let items: [TimelineItem]
    @Binding var isDraggingTask: Bool
    @Binding var isSheetDropTargeted: Bool
    @Binding var dragItemID: UUID?
    let heightForDuration: (Int) -> CGFloat
    let isSubscribed: Bool
    let onExpand: () -> Void
    var isTutorialHighlighted: Bool = false
    let onReturnToStock: (UUID) -> Void
    let onCreate: (_ title: String, _ durationMinutes: Int, _ priority: TaskPriority, _ startDate: Date?, _ endDate: Date?) -> Void
    let onUpdate: (_ id: UUID, _ title: String, _ durationMinutes: Int, _ priority: TaskPriority) -> Void
    let onDelete: (_ id: UUID) -> Void
    let onReorderStock: (_ from: IndexSet, _ to: Int) -> Void

    @State private var isCreateSheetPresented = false
    @State private var editingItemID: UUID?
    @State private var tutorialHighlightPulse = false

    private let cardShape = RoundedRectangle(cornerRadius: 28, style: .continuous)

    private var stockTasks: [TimelineItem] {
        items.filter { $0.dropDate == nil }
    }

    /// タイムライン上のアイテムをドラッグ中のみドロップを受け取る
    private var isDraggingPlacedItem: Bool {
        guard let dragItemID else { return false }
        return items.contains { $0.id == dragItemID && $0.dropDate != nil }
    }

    var body: some View {
        let secondary = AppColors.textSecondary(palette: themeManager.theme, environmentScheme: colorScheme)
        let primary = AppColors.textPrimary(palette: themeManager.theme, environmentScheme: colorScheme)
        let accent = AppColors.accent(palette: themeManager.theme, environmentScheme: colorScheme)

        VStack(spacing: 10) {
            Button {
                isCreateSheetPresented = true
                onExpand()
            } label: {
                HStack(spacing: 8) {
                    Text(isSheetDropTargeted ? "タスクリストへ戻す" : "Stock")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isSheetDropTargeted ? accent : primary)
                    Spacer()
                    if isSheetDropTargeted {
                        Image(systemName: "tray.and.arrow.down.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(accent)
                    } else {
                        if !stockTasks.isEmpty {
                            Text("\(stockTasks.count)件")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(secondary)
                        }
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(secondary)
                    }
                }
                .padding(.top, 2)
                .padding(.bottom, 2)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .allowsHitTesting(!isDraggingPlacedItem)

            // 空↔1件で View を差し替えると UICollectionView が再生成され、
            // 初回セルがレイアウトされないことがあるため常にマウントする
            ZStack(alignment: .leading) {
                HorizontalStockChipList(
                    items: stockTasks,
                    isDraggingTask: $isDraggingTask,
                    dragItemID: $dragItemID,
                    heightForDuration: heightForDuration,
                    themeManager: themeManager,
                    colorScheme: colorScheme,
                    onTap: { item in
                        editingItemID = item.id
                    },
                    onReorder: { from, to in
                        onReorderStock(from, to)
                    }
                )
                .opacity(stockTasks.isEmpty ? 0 : 1)
                .allowsHitTesting(!stockTasks.isEmpty && !isDraggingPlacedItem)

                if stockTasks.isEmpty {
                    Text(isSheetDropTargeted ? "ここにドロップ" : "タスクがありません")
                        .font(.system(size: 12))
                        .foregroundStyle(isSheetDropTargeted ? accent : secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .clipped()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .modifier(
            PeekCardLiquidGlassBackground(
                shape: cardShape,
                isDropTargeted: isSheetDropTargeted,
                accent: accent
            )
        )
        .clipShape(cardShape)
        .overlay {
            cardShape
                .strokeBorder(accent.opacity(isSheetDropTargeted ? 0.55 : 0), lineWidth: 1.5)
                .animation(.easeInOut(duration: 0.15), value: isSheetDropTargeted)
                .allowsHitTesting(false)
        }
        .overlay {
            if isTutorialHighlighted {
                cardShape
                    .stroke(
                        AppColors.strongAccent(palette: themeManager.theme, environmentScheme: colorScheme),
                        lineWidth: 3
                    )
                    .scaleEffect(tutorialHighlightPulse ? 1.03 : 1.0)
                    .opacity(tutorialHighlightPulse ? 0.35 : 0.95)
                    .animation(
                        .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                        value: tutorialHighlightPulse
                    )
                    .allowsHitTesting(false)
                    .onAppear { tutorialHighlightPulse = true }
            }
        }
        .overlay {
            ItemDropTarget(
                onDrop: { id in
                    isSheetDropTargeted = false
                    isDraggingTask = false
                    guard items.contains(where: { $0.id == id && $0.dropDate != nil }) else { return }
                    onReturnToStock(id)
                },
                onDragEntered: {
                    guard isDraggingPlacedItem else { return }
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.prepare()
                    generator.impactOccurred()
                    isSheetDropTargeted = true
                },
                onDragExited: {
                    isSheetDropTargeted = false
                },
                absorbsHits: isDraggingPlacedItem
            )
        }
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: $isCreateSheetPresented) {
            TaskCreateSheetView(
                isSubscribed: isSubscribed,
                onCancel: { isCreateSheetPresented = false },
                onCreate: { title, durationMinutes, priority, startDate, endDate in
                    onCreate(title, durationMinutes, priority, startDate, endDate)
                    isCreateSheetPresented = false
                }
            )
            .environmentObject(themeManager)
        }
        .sheet(item: editingItemBinding) { item in
            TaskEditSheetView(
                item: item,
                isSubscribed: isSubscribed,
                onCancel: { editingItemID = nil },
                onSave: { title, durationMinutes, priority in
                    onUpdate(item.id, title, durationMinutes, priority)
                    editingItemID = nil
                },
                onDelete: {
                    onDelete(item.id)
                    editingItemID = nil
                }
            )
            .environmentObject(themeManager)
        }
    }

    private var editingItemBinding: Binding<TimelineItem?> {
        Binding(
            get: {
                guard let editingItemID else { return nil }
                return items.first(where: { $0.id == editingItemID })
            },
            set: { item in
                editingItemID = item?.id
            }
        )
    }
}

/// TabView と同系の Liquid Glass。iOS 26 未満は Material で近似する。
private struct PeekCardLiquidGlassBackground: ViewModifier {
    let shape: RoundedRectangle
    let isDropTargeted: Bool
    let accent: Color

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(
                isDropTargeted ? .regular.tint(accent.opacity(0.35)) : .regular,
                in: shape
            )
        } else {
            content
                .background {
                    shape
                        .fill(.ultraThinMaterial)
                        .shadow(color: Color.black.opacity(0.12), radius: 16, x: 0, y: 6)
                }
                .background {
                    if isDropTargeted {
                        shape.fill(accent.opacity(0.12))
                    }
                }
        }
    }
}

#Preview("TaskListPeekCardView") {
    ZStack {
        LinearGradient(
            colors: [Color.blue.opacity(0.35), Color.purple.opacity(0.25), Color.orange.opacity(0.2)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        TaskListPeekCardView(
            items: [
                TimelineItem(title: "買い物", durationMinutes: 30),
                TimelineItem(title: "読書", durationMinutes: 45)
            ],
            isDraggingTask: .constant(false),
            isSheetDropTargeted: .constant(false),
            dragItemID: .constant(nil),
            heightForDuration: { CGFloat($0) / 60 * 80 },
            isSubscribed: true,
            onExpand: {},
            onReturnToStock: { _ in },
            onCreate: { _, _, _, _, _ in },
            onUpdate: { _, _, _, _ in },
            onDelete: { _ in },
            onReorderStock: { _, _ in }
        )
        .padding(.horizontal, 16)
    }
    .environmentObject(ThemeManager())
}
