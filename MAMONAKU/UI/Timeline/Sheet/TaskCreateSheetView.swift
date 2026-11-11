import SwiftUI

/// タスク作成シート。「日時を指定」をオンにするとタイムラインへ配置し、オフなら Stock に追加する。
/// 日時指定中は「繰り返す」で、終了日までの毎日または固定曜日に同じ時刻でまとめて作れる。
struct TaskCreateSheetView: View {
    @Environment(\.appTheme) private var theme

    let isSubscribed: Bool
    let onCancel: () -> Void
    /// startDate / endDate は「日時を指定」がオンのときだけ渡す。繰り返すときは repeatRule も渡す。
    /// 戻り値が false のときはシートを開いたままにする（置ける日が無かった）。
    let onCreate: (
        _ title: String,
        _ durationMinutes: Int,
        _ priority: TaskPriority,
        _ startDate: Date?,
        _ endDate: Date?,
        _ repeatRule: RoutineRepeat?
    ) -> Bool

    @State private var title = ""
    @State private var durationMinutes = 30
    @State private var priority: TaskPriority = .medium
    @State private var isDateSpecified = false
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(30 * 60)
    @State private var repeats = false
    @State private var selectedWeekdays: Set<Int> = []
    @State private var rangeEnd = Calendar.current.date(byAdding: .day, value: 28, to: Date()) ?? Date()
    @State private var sheetDetent: PresentationDetent = .medium
    @State private var isCreationErrorPresented = false

    private var calendar: Calendar { .current }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 開始・終了の指定が有効か（オンで、終了が開始より後）
    private var usesScheduleDates: Bool {
        isDateSpecified && resolvedEndDate > startDate
    }

    /// 繰り返し中は終了時刻を開始日の同じ日に合わせる。
    private var resolvedEndDate: Date {
        guard repeats, isDateSpecified else { return endDate }
        let time = calendar.dateComponents([.hour, .minute], from: endDate)
        return calendar.date(
            bySettingHour: time.hour ?? 0,
            minute: time.minute ?? 0,
            second: 0,
            of: startDate
        ) ?? endDate
    }

    private var startDay: Date {
        calendar.startOfDay(for: startDate)
    }

    private var maximumRangeEnd: Date {
        calendar.date(byAdding: .day, value: TimelineItemEditUseCase.maximumRoutineSpanDays, to: startDay) ?? startDay
    }

    private var canCreate: Bool {
        guard !trimmedTitle.isEmpty else { return false }
        guard isDateSpecified else { return true }
        guard resolvedEndDate > startDate else { return false }
        guard repeats else { return true }
        return !selectedWeekdays.isEmpty && calendar.startOfDay(for: rangeEnd) >= startDay
    }

    /// 日時指定のときは開始〜終了から求めた時間（5 分単位に切り捨て）、それ以外は選択した時間。
    private var resolvedDurationMinutes: Int {
        guard usesScheduleDates else { return durationMinutes }
        let raw = Int(resolvedEndDate.timeIntervalSince(startDate) / 60)
        return min(max(5, raw / 5 * 5), DayTime.minutesPerDay)
    }

    private var repeatEndTime: Binding<Date> {
        Binding(
            get: { resolvedEndDate },
            set: { endDate = $0 }
        )
    }

    private var everyDay: Binding<Bool> {
        Binding(
            get: { selectedWeekdays.count == 7 },
            set: { isOn in
                if isOn {
                    selectedWeekdays = Set(1...7)
                } else {
                    selectedWeekdays = [calendar.component(.weekday, from: startDate)]
                }
            }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                taskSection
                scheduleSection
                if isDateSpecified {
                    repeatSection
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
                        let didCreate = onCreate(
                            trimmedTitle,
                            resolvedDurationMinutes,
                            isSubscribed ? priority : .low,
                            usesScheduleDates ? startDate : nil,
                            usesScheduleDates ? resolvedEndDate : nil,
                            repeats && usesScheduleDates
                                ? RoutineRepeat(weekdays: selectedWeekdays, endDate: rangeEnd)
                                : nil
                        )
                        if !didCreate {
                            isCreationErrorPresented = true
                        }
                    }
                    .disabled(!canCreate)
                }
            }
            .onChange(of: isDateSpecified) { _, isSpecified in
                withAnimation(.snappy) {
                    sheetDetent = isSpecified ? .large : .medium
                }
                guard isSpecified else {
                    repeats = false
                    return
                }
                let now = Date()
                startDate = now
                endDate = now.addingTimeInterval(TimeInterval(durationMinutes * 60))
                clampRangeEnd()
            }
            .onChange(of: startDate) { _, newStart in
                guard isDateSpecified else { return }
                if !repeats, endDate <= newStart {
                    endDate = newStart.addingTimeInterval(TimeInterval(max(durationMinutes, 5) * 60))
                }
                if repeats, resolvedEndDate <= newStart {
                    endDate = newStart.addingTimeInterval(TimeInterval(max(durationMinutes, 5) * 60))
                }
                clampRangeEnd()
            }
            .onChange(of: repeats) { _, isOn in
                guard isOn else { return }
                if selectedWeekdays.isEmpty {
                    selectedWeekdays = [calendar.component(.weekday, from: startDate)]
                }
                endDate = resolvedEndDate
                clampRangeEnd()
                withAnimation(.snappy) {
                    sheetDetent = .large
                }
            }
            .alert("作成できません", isPresented: $isCreationErrorPresented) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("その期間に置ける日がありません。曜日や終了日を変えるか、重なっている予定をずらしてください。")
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
                if repeats {
                    DatePicker("終了時刻", selection: repeatEndTime, displayedComponents: .hourAndMinute)
                } else {
                    DatePicker("終了", selection: $endDate, displayedComponents: [.date, .hourAndMinute])
                }
            }
        } header: {
            Text("詳細")
        } footer: {
            if isDateSpecified, resolvedEndDate <= startDate {
                Text("終了は開始より後にしてください。")
            } else if repeats, usesScheduleDates {
                Text("選んだ曜日の開始日から終了日まで、同じ時刻でタイムラインに置きます。他の予定と重なる日は作りません。")
            } else if usesScheduleDates {
                Text("作成するとタイムライン上に配置されます。")
            } else {
                Text("オフの場合は Stock に追加されます。")
            }
        }
    }

    private var repeatSection: some View {
        Section {
            Toggle("繰り返す", isOn: $repeats.animation())
            if repeats {
                Toggle("毎日", isOn: everyDay.animation())
                RoutineWeekdayPicker(selectedWeekdays: $selectedWeekdays)
                DatePicker(
                    "終了日",
                    selection: $rangeEnd,
                    in: startDay...maximumRangeEnd,
                    displayedComponents: .date
                )
            }
        } footer: {
            if repeats, selectedWeekdays.isEmpty {
                Text("曜日を1つ以上選んでください。")
            }
        }
    }

    private func clampRangeEnd() {
        let day = calendar.startOfDay(for: rangeEnd)
        if day < startDay {
            rangeEnd = startDay
        } else if day > maximumRangeEnd {
            rangeEnd = maximumRangeEnd
        }
    }
}

#Preview("PLUS 加入中") {
    TaskCreateSheetView(isSubscribed: true, onCancel: {}, onCreate: { _, _, _, _, _, _ in true })
}

#Preview("未加入") {
    TaskCreateSheetView(isSubscribed: false, onCancel: {}, onCreate: { _, _, _, _, _, _ in true })
}
