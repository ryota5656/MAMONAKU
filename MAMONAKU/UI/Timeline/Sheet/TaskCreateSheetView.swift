import SwiftUI

/// タスク作成シート。「日時を指定」をオンにするとタイムラインへ配置し、オフなら Stock に追加する。
struct TaskCreateSheetView: View {
    @Environment(\.appTheme) private var theme

    let isSubscribed: Bool
    let onCancel: () -> Void
    /// startDate / endDate は「日時を指定」がオンのときだけ渡す。
    let onCreate: (_ title: String, _ durationMinutes: Int, _ priority: TaskPriority, _ startDate: Date?, _ endDate: Date?) -> Void

    @State private var title = ""
    @State private var durationMinutes = 30
    @State private var priority: TaskPriority = .medium
    @State private var isDateSpecified = false
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(30 * 60)
    @State private var sheetDetent: PresentationDetent = .medium

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 開始・終了の指定が有効か（オンで、終了が開始より後）
    private var usesScheduleDates: Bool {
        isDateSpecified && endDate > startDate
    }

    private var canCreate: Bool {
        !trimmedTitle.isEmpty && (!isDateSpecified || endDate > startDate)
    }

    /// 日時指定のときは開始〜終了から求めた時間（5 分単位に切り捨て）、それ以外は選択した時間。
    private var resolvedDurationMinutes: Int {
        guard usesScheduleDates else { return durationMinutes }
        let raw = Int(endDate.timeIntervalSince(startDate) / 60)
        return min(max(5, raw / 5 * 5), DayTime.minutesPerDay)
    }

    var body: some View {
        NavigationStack {
            Form {
                taskSection
                scheduleSection
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
                            trimmedTitle,
                            resolvedDurationMinutes,
                            isSubscribed ? priority : .low,
                            usesScheduleDates ? startDate : nil,
                            usesScheduleDates ? endDate : nil
                        )
                    }
                    .disabled(!canCreate)
                }
            }
            .onChange(of: isDateSpecified) { _, isSpecified in
                withAnimation(.snappy) {
                    // 開始・終了行が増えるのでシートを広げ、下部が隠れないようにする
                    sheetDetent = isSpecified ? .large : .medium
                }
                guard isSpecified else { return }
                let now = Date()
                startDate = now
                endDate = now.addingTimeInterval(TimeInterval(durationMinutes * 60))
            }
            .onChange(of: startDate) { _, newStart in
                // 終了が開始以前になったら、選択中の時間の分だけ後ろへずらす
                guard isDateSpecified, endDate <= newStart else { return }
                endDate = newStart.addingTimeInterval(TimeInterval(max(durationMinutes, 5) * 60))
            }
        }
        .presentationDetents([.medium, .large], selection: $sheetDetent)
        .presentationDragIndicator(.visible)
    }

    private var taskSection: some View {
        Section("タスク") {
            TextField("タイトル", text: $title)
                .submitLabel(.done)

            if usesScheduleDates {
                HStack {
                    Text("時間")
                    Spacer()
                    Text("\(resolvedDurationMinutes) min")
                        .foregroundStyle(theme.textSecondary)
                }
            } else {
                TaskDurationPickerRow(durationMinutes: $durationMinutes)
            }

            TaskPriorityRow(priority: $priority, isSubscribed: isSubscribed)
        }
    }

    private var scheduleSection: some View {
        Section {
            Toggle(isOn: $isDateSpecified.animation()) {
                Text("日時を指定")
            }

            if isDateSpecified {
                DatePicker("開始", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                DatePicker("終了", selection: $endDate, displayedComponents: [.date, .hourAndMinute])
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
}

#Preview("PLUS 加入中") {
    TaskCreateSheetView(isSubscribed: true, onCancel: {}, onCreate: { _, _, _, _, _ in })
}

#Preview("未加入") {
    TaskCreateSheetView(isSubscribed: false, onCancel: {}, onCreate: { _, _, _, _, _ in })
}
