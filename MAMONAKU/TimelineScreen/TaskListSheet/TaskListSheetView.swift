import SwiftUI
import UniformTypeIdentifiers

struct TaskListSheetView: View {
    let items: [TimelineItem]
    @Binding var isPresented: Bool
    @Binding var isDraggingTask: Bool
    @Binding var isSheetDropTargeted: Bool
    @Binding var dragItemID: UUID?
    @Binding var isSheetExpanded: Bool
    @Binding var isSheetDraggable: Bool
    let onMove: (IndexSet, Int) -> Void
    let onAdd: (String, Int) -> Void
    let onDelete: (UUID) -> Void
    @State private var editMode: EditMode = .inactive
    @State private var newTitle = ""
    @State private var newDurationMinutes = 30

    private var tasks: [TimelineItem] {
        items.filter { $0.dropDate == nil }
    }

    var body: some View {
        VStack(spacing: 12) {
            Capsule()
                .fill(Color.black.opacity(0.12))
                .frame(width: 44, height: 5)
                .padding(.top, 8)

            HStack(spacing: 12) {

                Text("Stock")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        editMode = editMode.isEditing ? .inactive : .active
                        isSheetDraggable = !editMode.isEditing
                    }
                } label: {
                    Text(editMode.isEditing ? "完了" : "並び替え")
                        .font(.system(size: 12, weight: .semibold))
                }
            }

            if tasks.isEmpty {
                VStack(spacing: 12) {
                    Text("タスクがありません")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .padding(.top, 12)
                    Spacer(minLength: 0)
                }
                .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach(tasks) { item in
                        TaskListRow(
                            item: item,
                            isDraggingTask: $isDraggingTask,
                            dragItemID: $dragItemID,
                            onDelete: onDelete
                        )
                        .listRowInsets(.init(top: .zero, leading: 20, bottom: .zero, trailing: .zero))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                    .onMove(perform: onMove)
                }
                .listStyle(.plain)
                .environment(\.editMode, $editMode)
                .frame(maxHeight: .infinity)
                .environment(\.defaultMinListRowHeight, 44)


            }

            Divider()

            taskInputRow
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .onDrop(of: [UTType.text], isTargeted: $isSheetDropTargeted) { _ in
            false
        }
        .onChange(of: isSheetDropTargeted) { _, isTargeted in
            guard isDraggingTask, !isTargeted else { return }
            isDraggingTask = false
            isPresented = false
        }
        .onAppear {
            isSheetDraggable = !editMode.isEditing
        }
        .onChange(of: editMode) { _, mode in
            isSheetDraggable = !mode.isEditing
        }
    }

    private var canAdd: Bool {
        !newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var taskInputRow: some View {
        HStack {
            TextField("タスクを追加", text: $newTitle)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )

            durationMenu

            Button {
                onAdd(newTitle, newDurationMinutes)
                newTitle = ""
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(canAdd ? Color.accentColor : Color.secondary)
            }
            .disabled(!canAdd)
        }
    }

    private var durationMenu: some View {
        Menu {
            Picker("", selection: $newDurationMinutes) {
                ForEach(Array(stride(from: 15, through: 240, by: 15)), id: \.self) { minutes in
                    Text("\(minutes) min")
                        .font(.system(size: 10))
                }
            }
            .tint(.black)
        } label: {
            Text("\(newDurationMinutes) min")
                .font(.system(size: 12, weight: .semibold))
                .tint(Color.black)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
        }
    }
}

private struct TaskListRow: View {
    let item: TimelineItem
    @Binding var isDraggingTask: Bool
    @Binding var dragItemID: UUID?
    let onDelete: (UUID) -> Void
    @Environment(\.editMode) private var editMode

    var body: some View {
        Group {
            if isDragEnabled {
                rowContent
                    .onDrag {
                        isDraggingTask = true
                        dragItemID = item.id
                        return NSItemProvider(object: item.id.uuidString as NSString)
                    } preview: {
                        TaskDragPreview(item: item)
                    }
            } else {
                rowContent
            }
        }
    }

    private var isDragEnabled: Bool {
        !(editMode?.wrappedValue.isEditing ?? false)
    }

    private var rowContent: some View {
        HStack {
            if isEditing {
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
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 14, weight: .semibold))
                Text("\(item.durationMinutes) min")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
    }

    private var isEditing: Bool {
        editMode?.wrappedValue.isEditing ?? false
    }
}

private struct TaskDragPreview: View {
    let item: TimelineItem

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.black)
                .frame(width: 6, height: 34)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
                Text("\(item.durationMinutes) min")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .frame(width: 180)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 6)
        )
    }
}

#Preview {
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
        isSheetDraggable: .constant(true),
        onMove: { _, _ in },
        onAdd: { _, _ in },
        onDelete: { _ in }
    )
}
