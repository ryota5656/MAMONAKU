import SwiftUI

/// ルーティン一覧から開く編集画面。保存すると、まだ紐づいている予定へ反映する。
struct RoutineEditSheetView: View {
    @Environment(\.appTheme) private var theme

    let routine: TimelineRoutine
    let isSubscribed: Bool
    let onCancel: () -> Void
    /// 保存できたときは true。できなかったときは画面を開いたままにする。
    let onSave: (
        _ title: String,
        _ priority: TaskPriority,
        _ startDate: Date,
        _ endDate: Date,
        _ repeatRule: RoutineRepeat
    ) -> Bool

    @State private var title: String
    @State private var priority: TaskPriority
    @State private var startDay: Date
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var rangeEnd: Date
    @State private var selectedWeekdays: Set<Int>
    @State private var isSaveErrorPresented = false

    init(
        routine: TimelineRoutine,
        isSubscribed: Bool,
        onCancel: @escaping () -> Void,
        onSave: @escaping (
            _ title: String,
            _ priority: TaskPriority,
            _ startDate: Date,
            _ endDate: Date,
            _ repeatRule: RoutineRepeat
        ) -> Bool
    ) {
        self.routine = routine
        self.isSubscribed = isSubscribed
        self.onCancel = onCancel
        self.onSave = onSave
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .minute, value: routine.startMinutes, to: routine.startDate) ?? routine.startDate
        let end = calendar.date(
            byAdding: .minute,
            value: routine.startMinutes + routine.durationMinutes,
            to: routine.startDate
        ) ?? start
        _title = State(initialValue: routine.title)
        _priority = State(initialValue: isSubscribed ? routine.priority : .low)
        _startDay = State(initialValue: routine.startDate)
        _startTime = State(initialValue: start)
        _endTime = State(initialValue: end)
        _rangeEnd = State(initialValue: routine.endDate)
        _selectedWeekdays = State(initialValue: routine.weekdaySet)
    }

    private var calendar: Calendar { .current }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var startDate: Date {
        date(on: startDay, time: startTime)
    }

    private var endDate: Date {
        date(on: startDay, time: endTime)
    }

    private var maximumRangeEnd: Date {
        calendar.date(byAdding: .day, value: TimelineItemEditUseCase.maximumRoutineSpanDays, to: calendar.startOfDay(for: startDay))
            ?? startDay
    }

    private var resolvedDurationMinutes: Int {
        let raw = Int(endDate.timeIntervalSince(startDate) / 60)
        return min(max(5, raw / 5 * 5), DayTime.minutesPerDay)
    }

    private var canSave: Bool {
        !trimmedTitle.isEmpty
            && endDate > startDate
            && !selectedWeekdays.isEmpty
            && calendar.startOfDay(for: rangeEnd) >= calendar.startOfDay(for: startDay)
    }

    private var everyDay: Binding<Bool> {
        Binding(
            get: { selectedWeekdays.count == 7 },
            set: { isOn in
                if isOn {
                    selectedWeekdays = Set(1...7)
                } else {
                    selectedWeekdays = [calendar.component(.weekday, from: startDay)]
                }
            }
        )
    }

    var body: some View {
        Form {
            Section("タスク") {
                TextField("タイトル", text: $title)
                    .submitLabel(.done)
                HStack {
                    Text("時間")
                    Spacer()
                    Text("\(resolvedDurationMinutes) min")
                        .foregroundStyle(theme.textSecondary)
                }
                TaskPriorityRow(priority: $priority, isSubscribed: isSubscribed)
            }

            Section {
                DatePicker("開始日", selection: $startDay, displayedComponents: .date)
                DatePicker("開始時刻", selection: $startTime, displayedComponents: .hourAndMinute)
                DatePicker("終了時刻", selection: $endTime, displayedComponents: .hourAndMinute)
            } footer: {
                if endDate <= startDate {
                    Text("終了は開始より後にしてください。")
                }
            }

            Section {
                Toggle("毎日", isOn: everyDay.animation())
                RoutineWeekdayPicker(selectedWeekdays: $selectedWeekdays)
                DatePicker(
                    "終了日",
                    selection: $rangeEnd,
                    in: calendar.startOfDay(for: startDay)...maximumRangeEnd,
                    displayedComponents: .date
                )
            } footer: {
                if selectedWeekdays.isEmpty {
                    Text("曜日を1つ以上選んでください。")
                } else {
                    Text("まだこのルーティンに属している予定へ反映します。曜日や期間から外した日は削除します。新しい時刻が他の予定と重なる日は、元の時刻のままルーティンから外れます。")
                }
            }
        }
        .presentationDetents([.large])
        .navigationTitle("ルーティンを編集")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル", action: onCancel)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    let didSave = onSave(
                        trimmedTitle,
                        isSubscribed ? priority : .low,
                        startDate,
                        endDate,
                        RoutineRepeat(weekdays: selectedWeekdays, endDate: rangeEnd)
                    )
                    if !didSave {
                        isSaveErrorPresented = true
                    }
                }
                .disabled(!canSave)
            }
        }
        .onChange(of: startDay) { _, _ in
            clampRangeEnd()
        }
        .alert("保存できません", isPresented: $isSaveErrorPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("その内容だと、ルーティンに残せる日がありません。曜日や時刻を変えてください。")
        }
    }

    private func date(on day: Date, time: Date) -> Date {
        let parts = calendar.dateComponents([.hour, .minute], from: time)
        return calendar.date(
            bySettingHour: parts.hour ?? 0,
            minute: parts.minute ?? 0,
            second: 0,
            of: day
        ) ?? day
    }

    private func clampRangeEnd() {
        let start = calendar.startOfDay(for: startDay)
        let day = calendar.startOfDay(for: rangeEnd)
        if day < start {
            rangeEnd = start
        } else if day > maximumRangeEnd {
            rangeEnd = maximumRangeEnd
        }
    }
}
