import SwiftUI

/// ピークカードから開くタスク作成モーダル。`TaskEditSheetView` のデザインを踏襲する。
struct TaskCreateSheetView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    let isSubscribed: Bool
    let onCancel: () -> Void
    /// start/end が両方ある場合はタイムライン配置、なければ Stock 追加
    let onCreate: (_ title: String, _ durationMinutes: Int, _ priority: TaskPriority, _ startDate: Date?, _ endDate: Date?) -> Void

    @State private var title = ""
    @State private var durationMinutes = 30
    @State private var priority: TaskPriority = .medium
    @State private var isDateSpecified = false
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(30 * 60)
    @State private var sheetDetent: PresentationDetent = .medium

    private var canCreate: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && dateSelectionIsValid
    }

    private var dateSelectionIsValid: Bool {
        !isDateSpecified || endDate > startDate
    }

    private var resolvedDurationMinutes: Int {
        guard isDateSpecified, endDate > startDate else {
            return durationMinutes
        }
        let raw = Int(endDate.timeIntervalSince(startDate) / 60)
        let snapped = max(5, (raw / 5) * 5)
        return min(snapped, 24 * 60)
    }

    private var usesScheduleDates: Bool {
        isDateSpecified && endDate > startDate
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("タスク") {
                    TextField("タイトル", text: $title)
                        .submitLabel(.done)

                    if usesScheduleDates {
                        HStack {
                            Text("時間")
                            Spacer()
                            Text("\(resolvedDurationMinutes) min")
                                .foregroundStyle(
                                    AppColors.textSecondary(
                                        palette: themeManager.theme,
                                        environmentScheme: colorScheme
                                    )
                                )
                        }
                    } else {
                        Picker("時間", selection: $durationMinutes) {
                            ForEach(Array(stride(from: 5, through: 480, by: 5)), id: \.self) { minutes in
                                Text("\(minutes) min")
                                    .tag(minutes)
                            }
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
                                .foregroundStyle(
                                    AppColors.textSecondary(
                                        palette: themeManager.theme,
                                        environmentScheme: colorScheme
                                    )
                                )
                        }
                    }
                }

                Section {
                    Toggle(isOn: $isDateSpecified.animation()) {
                        Text("日時を指定")
                    }

                    if isDateSpecified {
                        DatePicker(
                            "開始",
                            selection: $startDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )

                        DatePicker(
                            "終了",
                            selection: $endDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }
                } header: {
                    Text("詳細")
                } footer: {
                    if isDateSpecified, endDate <= startDate {
                        Text("終了は開始より後にしてください。")
                    } else if usesScheduleDates {
                        Text("作成するとタイムライン上に配置されます。")
                    } else {
                        Text("オフの場合は Stock に追加されます。")
                    }
                }
            }
            .navigationTitle("タスクを作成")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("作成") {
                        onCreate(
                            title.trimmingCharacters(in: .whitespacesAndNewlines),
                            resolvedDurationMinutes,
                            isSubscribed ? priority : .low,
                            usesScheduleDates ? startDate : nil,
                            usesScheduleDates ? endDate : nil
                        )
                    }
                    .disabled(!canCreate)
                }
            }
            .onChange(of: isDateSpecified) { _, enabled in
                withAnimation(.snappy) {
                    // 開始・終了行が増えるのでシートを広げ、下部が隠れないようにする
                    sheetDetent = enabled ? .large : .medium
                }
                guard enabled else { return }
                let now = Date()
                startDate = now
                endDate = now.addingTimeInterval(TimeInterval(durationMinutes * 60))
            }
            .onChange(of: startDate) { _, newStart in
                guard isDateSpecified, endDate <= newStart else { return }
                endDate = newStart.addingTimeInterval(TimeInterval(max(durationMinutes, 5) * 60))
            }
        }
        .presentationDetents([.medium, .large], selection: $sheetDetent)
        .presentationDragIndicator(.visible)
    }
}

#Preview("TaskCreateSheetView - subscribed") {
    TaskCreateSheetView(
        isSubscribed: true,
        onCancel: {},
        onCreate: { _, _, _, _, _ in }
    )
    .environmentObject(ThemeManager())
}
