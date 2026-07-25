import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct TaskListSheetView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    let items: [TimelineItem]
    @Binding var isPresented: Bool
    @Binding var isDraggingTask: Bool
    @Binding var isSheetDropTargeted: Bool
    @Binding var dragItemID: UUID?
    @Binding var isSheetExpanded: Bool
    @Binding var sheetDetent: PresentationDetent
    @Binding var isSheetDraggable: Bool
    let onMove: (IndexSet, Int) -> Void
    let onAdd: (String, Int, TaskPriority) -> Void
    let onDelete: (UUID) -> Void
    let onUpdate: (UUID, String, Int, TaskPriority) -> Void
    let onReturnToStock: (UUID) -> Void
    /// ドラッグプレビュー等の高さをタイムラインと揃える（ViewModel.heightForDuration を渡す）
    let heightForDuration: (Int) -> CGFloat
    /// Debug ビルド用: 指定分後に15分のテストタスクを置く
    var onAddDebugTask: ((Int) -> Void)?
    /// サブスクリプション未加入の場合は優先度を Low のみで登録
    var isSubscribed: Bool = false
    @State private var editMode: EditMode = .inactive
    @State private var newTitle = ""
    @State private var newDurationMinutes = 30
    @State private var newPriority: TaskPriority = .medium
    @State private var showTimelineItems = true
    @State private var editingItemID: UUID?
    /// キーボード表示時の detent 変化とキーボード押上のアニメ差を緩衝する
    @State private var keyboardSyncedMaxHeight: CGFloat?
    @FocusState private var isTaskInputFocused: Bool

    private var stockTasks: [TimelineItem] {
        items.filter { $0.dropDate == nil }
    }

    private var timelineTasks: [TimelineItem] {
        items.filter { $0.dropDate != nil }
    }

    var body: some View {
        let secondary = AppColors.textSecondary(palette: themeManager.theme, environmentScheme: colorScheme)
        let accent = AppColors.accent(palette: themeManager.theme, environmentScheme: colorScheme)

        VStack(spacing: 12) {
            expandedListContent(secondary: secondary)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            taskInputAccessory(secondary: secondary)
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(accent.opacity(isSheetDropTargeted ? 0.14 : 0))
                .animation(.easeInOut(duration: 0.15), value: isSheetDropTargeted)
        )
        .overlay {
            ItemDropTarget(
                onDrop: { id in
                    isSheetDropTargeted = false
                    isDraggingTask = false
                    onReturnToStock(id)
                },
                onDragEntered: {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.prepare()
                    generator.impactOccurred()
                    isSheetDropTargeted = true
                },
                onDragExited: {
                    isSheetDropTargeted = false
                }
            )
        }
        // medium → large の detent 変化とキーボード押上のズレで一度飛び上がるのを抑える
        .frame(maxHeight: keyboardSyncedMaxHeight)
        .frame(maxHeight: .infinity)
        .onGeometryChange(for: CGFloat.self, of: \.size.height) { height in
            withAnimation(.spring(duration: 0.25)) {
                keyboardSyncedMaxHeight = height
            }
        }
        .onAppear {
            isSheetDraggable = !editMode.isEditing
        }
        .onChange(of: editMode) { _, mode in
            isSheetDraggable = !mode.isEditing
        }
        .sheet(item: editingItemBinding) { item in
            TaskEditSheetView(
                item: item,
                isSubscribed: isSubscribed,
                onCancel: {
                    editingItemID = nil
                },
                onSave: { title, durationMinutes, priority in
                    onUpdate(item.id, title, durationMinutes, isSubscribed ? priority : .low)
                    editingItemID = nil
                }
            )
            .environmentObject(themeManager)
        }
    }

    @ViewBuilder
    private func expandedListContent(secondary: Color) -> some View {
        TaskListSheetHeaderBar(
            hasTimelineTasks: !timelineTasks.isEmpty,
            showTimelineItems: $showTimelineItems,
            editMode: $editMode,
            isSheetDraggable: $isSheetDraggable,
            onAddDebugTask: onAddDebugTask
        )

        if stockTasks.isEmpty && (timelineTasks.isEmpty || !showTimelineItems) {
            VStack(spacing: 12) {
                Text("タスクがありません")
                    .font(.system(size: 13))
                    .foregroundStyle(secondary)
                    .padding(.top, 12)
                Spacer(minLength: 0)
            }
            .frame(maxHeight: .infinity)
        } else {
            List {
                ForEach(stockTasks) { item in
                    TaskListRowView(
                        item: item,
                        isOnTimeline: false,
                        isDraggingTask: $isDraggingTask,
                        dragItemID: $dragItemID,
                        onDelete: onDelete,
                        onEdit: { editingItemID = item.id },
                        heightForDuration: heightForDuration
                    )
                    .listRowInsets(.init(top: .zero, leading: 20, bottom: .zero, trailing: .zero))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
                .onMove(perform: onMove)

                if !timelineTasks.isEmpty && showTimelineItems {
                    Section {
                        ForEach(timelineTasks) { item in
                            TaskListRowView(
                                item: item,
                                isOnTimeline: true,
                                isDraggingTask: $isDraggingTask,
                                dragItemID: $dragItemID,
                                onDelete: onDelete,
                                onEdit: { editingItemID = item.id },
                                heightForDuration: heightForDuration
                            )
                            .listRowInsets(.init(top: .zero, leading: 20, bottom: .zero, trailing: .zero))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        }
                    } header: {
                        Text("タイムラインに配置済み")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(secondary)
                    }
                }
            }
            .listStyle(.plain)
            .scrollDismissesKeyboard(.interactively)
            .environment(\.editMode, $editMode)
            .frame(maxHeight: .infinity)
            .environment(\.defaultMinListRowHeight, 44)
        }
    }

    private func taskInputAccessory(secondary: Color) -> some View {
        VStack(spacing: 8) {
            Divider()

            TaskInputRow(
                isSubscribed: isSubscribed,
                title: $newTitle,
                durationMinutes: $newDurationMinutes,
                priority: $newPriority,
                isTaskInputFocused: $isTaskInputFocused,
                onSubmit: { title, minutes, priority in
                    onAdd(title, minutes, priority)
                }
            )
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
//        .background(.ultraThinMaterial)
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

    private var canAdd: Bool {
        !newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

#Preview("リストシート") {
    TaskListSheetView(
        items: [
        TimelineItem(title: "タスクA", durationMinutes: 30),
        TimelineItem(title: "タスクB", durationMinutes: 45)
        ],
        isPresented: .constant(true),
        isDraggingTask: .constant(false),
        isSheetDropTargeted: .constant(true),
        dragItemID: .constant(nil),
        isSheetExpanded: .constant(false),
        sheetDetent: .constant(TaskSheetPresentation.medium),
        isSheetDraggable: .constant(true),
        onMove: { _, _ in },
        onAdd: { _, _, _ in },
        onDelete: { _ in },
        onUpdate: { _, _, _, _ in },
        onReturnToStock: { _ in },
        heightForDuration: { CGFloat($0) / 60 * 80 }
    )
    .environmentObject(ThemeManager())
}

#Preview("ピーク表示") {
    TaskListPeekCardView(
        items: [
            TimelineItem(title: "買い物", durationMinutes: 30),
            TimelineItem(title: "読書", durationMinutes: 45),
            TimelineItem(title: "ジム", durationMinutes: 60),
            TimelineItem(title: "メール返信", durationMinutes: 15)
        ],
        isDraggingTask: .constant(false),
        isSheetDropTargeted: .constant(false),
        dragItemID: .constant(nil),
        heightForDuration: { CGFloat($0) / 60 * 80 },
        onExpand: {},
        onReturnToStock: { _ in }
    )
    .environmentObject(ThemeManager())
}
