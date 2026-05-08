import SwiftUI
import UniformTypeIdentifiers

struct TaskListSheetView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    let items: [TimelineItem]
    @Binding var isPresented: Bool
    @Binding var isDraggingTask: Bool
    @Binding var isSheetDropTargeted: Bool
    @Binding var dragItemID: UUID?
    @Binding var isSheetExpanded: Bool
    @Binding var isSheetDraggable: Bool
    let onMove: (IndexSet, Int) -> Void
    let onAdd: (String, Int, TaskPriority) -> Void
    let onDelete: (UUID) -> Void
    let onUpdate: (UUID, String, Int, TaskPriority) -> Void
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
    @FocusState private var isTaskInputFocused: Bool

    private var stockTasks: [TimelineItem] {
        items.filter { $0.dropDate == nil }
    }

    private var timelineTasks: [TimelineItem] {
        items.filter { $0.dropDate != nil }
    }

    var body: some View {
        let secondary = AppColors.textSecondary(palette: themeManager.theme, environmentScheme: colorScheme)
        let primary = AppColors.textPrimary(palette: themeManager.theme, environmentScheme: colorScheme)
        let accent = AppColors.strongAccent(palette: themeManager.theme, environmentScheme: colorScheme)

        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Text("Stock")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(primary)
                Spacer()
                if !timelineTasks.isEmpty {
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
                        TaskListRow(
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
                                TaskListRow(
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

    private var taskInputRow: some View {
        HStack(spacing: 8) {
            if isSubscribed {
                Menu {
                    Picker("優先度", selection: $newPriority) {
                        ForEach(TaskPriority.allCases, id: \.rawValue) { p in
                            Label(p.displayName, systemImage: p.iconName)
                                .tag(p)
                        }
                    }
                    .pickerStyle(.inline)
                } label: {
                    PriorityIconView(
                        priority: newPriority,
                        color: priorityColor(for: newPriority),
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

            TextField("タスクを追加", text: $newTitle)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
                .submitLabel(.next)
                .focused($isTaskInputFocused)
                .onSubmit {
                    guard canAdd else { return }
                    let priority = isSubscribed ? newPriority : TaskPriority.low
                    onAdd(newTitle.trimmingCharacters(in: .whitespacesAndNewlines), newDurationMinutes, priority)
                    newTitle = ""
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isTaskInputFocused = true
                    }
                }

            durationMenu

            Button {
                let priority = isSubscribed ? newPriority : TaskPriority.low
                onAdd(newTitle, newDurationMinutes, priority)
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
                ForEach(Array(stride(from: 15, through: 480, by: 5)), id: \.self) { minutes in
                    Text("\(minutes) min")
                        .foregroundStyle(AppColors.strongAccent(palette: themeManager.theme, environmentScheme: colorScheme))
                        .font(.system(size: 10))
                }
            }
            .tint(.primary)
        } label: {
            Text("\(newDurationMinutes) min")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppColors.strongAccent(palette: themeManager.theme, environmentScheme: colorScheme))
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
        }
    }

    private func priorityColor(for priority: TaskPriority) -> Color {
        switch priority {
        case .low:
            return AppColors.textSecondary(palette: themeManager.theme, environmentScheme: colorScheme)
        case .medium:
            return AppColors.accent(palette: themeManager.theme, environmentScheme: colorScheme)
        case .high:
            return AppColors.strongAccent(palette: themeManager.theme, environmentScheme: colorScheme)
        }
    }
}

private struct TaskListRow: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    let item: TimelineItem
    let isOnTimeline: Bool
    @Binding var isDraggingTask: Bool
    @Binding var dragItemID: UUID?
    let onDelete: (UUID) -> Void
    let onEdit: () -> Void
    let heightForDuration: (Int) -> CGFloat
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

    private var textColor: Color {
        if isOnTimeline { return AppColors.textSecondary(palette: themeManager.theme, environmentScheme: colorScheme) }
        return .primary
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

private struct TaskEditSheetView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    let item: TimelineItem
    let isSubscribed: Bool
    let onCancel: () -> Void
    let onSave: (String, Int, TaskPriority) -> Void
    @State private var title: String
    @State private var durationMinutes: Int
    @State private var priority: TaskPriority
    @FocusState private var isTitleFocused: Bool

    init(
        item: TimelineItem,
        isSubscribed: Bool,
        onCancel: @escaping () -> Void,
        onSave: @escaping (String, Int, TaskPriority) -> Void
    ) {
        self.item = item
        self.isSubscribed = isSubscribed
        self.onCancel = onCancel
        self.onSave = onSave
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
                        .focused($isTitleFocused)
                        .submitLabel(.done)

                    Picker("時間", selection: $durationMinutes) {
                        ForEach(Array(stride(from: 15, through: 480, by: 5)), id: \.self) { minutes in
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
                ToolbarItem(placement: .confirmationAction) {
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
        }
        .presentationDetents([.medium])
        .onAppear {
            isTitleFocused = true
        }
    }
}

private struct TaskDragPreview: View {
    @Environment(\.colorScheme) private var colorScheme
    let item: TimelineItem
    let height: CGFloat

    var body: some View {
        let accent = Color.accentColor
        let shadow = colorScheme == .dark ? Color.black.opacity(0.35) : Color.black.opacity(0.15)
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(accent)
                .frame(width: 6)
                .frame(maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
                Text("\(item.durationMinutes) min")
                    .font(.system(size: 10))
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
                Spacer(minLength: 0)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .frame(width: 180, height: height)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: shadow, radius: 10, x: 0, y: 6)
        )
    }
}

struct PriorityIconView: View {
    let priority: TaskPriority
    var color: Color = .secondary
    var size: CGFloat = 14

    var body: some View {
        ZStack {
            Circle()
                .stroke(color, lineWidth: 1)
            Image(systemName: priority.iconName)
                .font(.system(size: size * 0.55))
                .foregroundStyle(color)
        }
        .frame(width: size, height: size)
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
        onAdd: { _, _, _ in },
        onDelete: { _ in },
        onUpdate: { _, _, _, _ in },
        heightForDuration: { CGFloat($0) / 60 * 80 }
    )
    .environmentObject(ThemeManager())
}
