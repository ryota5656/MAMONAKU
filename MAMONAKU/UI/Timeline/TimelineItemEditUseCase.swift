import Foundation

/// タイムライン長押しで作成中の仮配置。
nonisolated struct PendingPlacement: Equatable, Sendable {
    /// 配置先の日（その日の 0 時）
    var date: Date
    var startMinutes: Int
    var durationMinutes: Int
    /// false: 長押ししたまま長さを決めている途中 / true: 指を離してタイトル入力待ち
    var isAwaitingTitle: Bool
}

/// 予定一覧に対する編集ルール（配置・移動・リサイズ・作成・更新）。
///
/// 状態を持たず、「編集前の一覧」を受け取って「編集後の一覧」を返す。
/// 他の予定と重なる等でその編集ができない場合は nil を返す。
nonisolated struct TimelineItemEditUseCase: Sendable {
    /// ドロップ位置を丸める刻み
    static let dropStepMinutes = 5
    /// リサイズ・編集で許す最短の所要時間
    static let minimumDurationMinutes = 15
    /// リサイズで所要時間を丸める刻み
    static let resizeStepMinutes = 5
    /// 長押しで仮配置するときの初期の所要時間
    static let longPressDurationMinutes = 30
    /// 長押し仮配置の開始時刻・長さを丸める刻み
    static let longPressStepMinutes = 5
    /// 日時指定で作成するときに所要時間を丸める刻み（端数は切り捨て）
    static let createStepMinutes = 5
    /// ルーティンの開始日〜終了日の最大日数（両端を含む。365 なら 366 日）
    static let maximumRoutineSpanDays = 365

    var calendar: Calendar = .current

    // MARK: - ドロップによる配置・移動

    /// ドロップ位置に置いた場合の見た目（重なりは確認しない）。
    func dropPreview(of item: TimelineItem, atMinutes rawMinutes: Int, on date: Date) -> TimelineItem {
        var preview = item
        preview.startMinutes = startMinutes(forDropAt: rawMinutes, durationMinutes: item.durationMinutes)
        preview.dropDate = calendar.startOfDay(for: date)
        return preview
    }

    /// Stock の予定を配置する、または配置済みの予定を移動する。
    func place(
        itemID: UUID,
        atMinutes rawMinutes: Int,
        on date: Date,
        in items: [TimelineItem]
    ) -> [TimelineItem]? {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return nil }
        let duration = items[index].durationMinutes
        let start = startMinutes(forDropAt: rawMinutes, durationMinutes: duration)
        guard !isOverlapping(start: start, duration: duration, excluding: itemID, on: date, in: items) else {
            return nil
        }

        var updated = items
        applyScheduleChange(
            to: &updated[index],
            startMinutes: start,
            dropDate: calendar.startOfDay(for: date),
            durationMinutes: duration
        )
        return updated
    }

    /// 配置済みの予定を Stock に戻す。
    func returnToStock(itemID: UUID, in items: [TimelineItem]) -> [TimelineItem]? {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return nil }
        var updated = items
        applyScheduleChange(
            to: &updated[index],
            startMinutes: nil,
            dropDate: nil,
            durationMinutes: updated[index].durationMinutes
        )
        return updated
    }

    // MARK: - リサイズ

    /// リサイズ中の見た目（重なりは確認しない）。開始時刻が無い予定は nil。
    func resizePreview(of item: TimelineItem, deltaMinutes: Int, fallbackDate: Date) -> TimelineItem? {
        guard item.startMinutes != nil else { return nil }
        var preview = item
        preview.durationMinutes = resizedDuration(of: item, deltaMinutes: deltaMinutes)
        preview.dropDate = calendar.startOfDay(for: item.dropDate ?? fallbackDate)
        return preview
    }

    /// 所要時間を `deltaMinutes` だけ伸縮する。
    func resize(
        itemID: UUID,
        deltaMinutes: Int,
        fallbackDate: Date,
        in items: [TimelineItem]
    ) -> [TimelineItem]? {
        guard let index = items.firstIndex(where: { $0.id == itemID }),
              let start = items[index].startMinutes
        else { return nil }
        let duration = resizedDuration(of: items[index], deltaMinutes: deltaMinutes)
        let date = items[index].dropDate ?? fallbackDate
        guard !isOverlapping(start: start, duration: duration, excluding: itemID, on: date, in: items) else {
            return nil
        }

        var updated = items
        applyScheduleChange(
            to: &updated[index],
            startMinutes: start,
            dropDate: items[index].dropDate,
            durationMinutes: duration
        )
        return updated
    }

    // MARK: - 長押しによる仮配置

    /// 長押しを始めた位置に、初期の長さで仮配置する。空きが足りない場合は nil。
    func beginPendingPlacement(atMinutes rawMinutes: Int, on date: Date, in items: [TimelineItem]) -> PendingPlacement? {
        let step = Self.longPressStepMinutes
        let start = clampStart(
            snap(rawMinutes, step: step),
            durationMinutes: Self.longPressDurationMinutes
        )
        let duration = pendingDuration(
            start: start,
            proposedDuration: Self.longPressDurationMinutes,
            on: date,
            in: items
        )
        guard duration >= step,
              !isOverlapping(start: start, duration: duration, excluding: nil, on: date, in: items)
        else { return nil }

        return PendingPlacement(
            date: calendar.startOfDay(for: date),
            startMinutes: start,
            durationMinutes: duration,
            isAwaitingTitle: false
        )
    }

    /// 長押ししたまま指を動かしたとき、開始時刻は固定で長さだけを指の位置に合わせる。
    func extendPendingPlacement(
        _ pending: PendingPlacement,
        toMinutes rawEndMinutes: Int,
        in items: [TimelineItem]
    ) -> PendingPlacement {
        let step = Self.longPressStepMinutes
        let proposed = max(step, snap(rawEndMinutes, step: step) - pending.startMinutes)
        var updated = pending
        updated.durationMinutes = pendingDuration(
            start: pending.startMinutes,
            proposedDuration: proposed,
            on: pending.date,
            in: items
        )
        return updated
    }

    /// 仮配置の長さを、1 日の終わりと後続の予定の手前までに収める（収まらなければ 0）。
    private func pendingDuration(start: Int, proposedDuration: Int, on date: Date, in items: [TimelineItem]) -> Int {
        let step = Self.longPressStepMinutes
        var duration = max(step, min(proposedDuration, DayTime.minutesPerDay - start))

        let nextStart = items
            .filter { $0.isPlaced(on: date, calendar: calendar) }
            .compactMap(\.startMinutes)
            .filter { $0 >= start }
            .min()
        if let nextStart {
            duration = min(duration, max(0, nextStart - start))
        }

        while duration >= step,
              isOverlapping(start: start, duration: duration, excluding: nil, on: date, in: items) {
            duration -= step
        }
        return max(0, duration)
    }

    // MARK: - 作成

    /// 新しい予定の追加結果。
    nonisolated struct Creation: Equatable, Sendable {
        nonisolated enum Placement: Equatable, Sendable {
            /// Stock に追加した
            case stock
            /// タイムラインに配置した
            case timeline
        }

        let items: [TimelineItem]
        let createdItem: TimelineItem
        let placement: Placement
        /// 繰り返しで作ったときだけ入る
        let routine: TimelineRoutine?
    }

    /// 予定を追加する。
    ///
    /// 開始・終了の指定があればタイムラインに配置し、指定が無い（または他の予定と重なる）場合は Stock に追加する。
    /// タイトルが空の場合は nil。
    func create(
        title: String,
        durationMinutes: Int,
        priority: TaskPriority,
        startDate: Date?,
        endDate: Date?,
        in items: [TimelineItem]
    ) -> Creation? {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }

        var newItem = TimelineItem(title: title, durationMinutes: durationMinutes, priority: priority)
        var placement = Creation.Placement.stock

        if let startDate, let endDate, endDate > startDate {
            let day = calendar.startOfDay(for: startDate)
            let start = Int(startDate.timeIntervalSince(day) / 60)
            let rawDuration = Int(endDate.timeIntervalSince(startDate) / 60)
            let step = Self.createStepMinutes
            newItem.durationMinutes = clampDuration(max(step, rawDuration / step * step), start: start)

            if !isOverlapping(start: start, duration: newItem.durationMinutes, excluding: nil, on: day, in: items) {
                newItem.startMinutes = start
                newItem.dropDate = day
                placement = .timeline
            }
        }

        return Creation(items: items + [newItem], createdItem: newItem, placement: placement, routine: nil)
    }

    /// 開始日〜終了日のうち、選んだ曜日に同じ時刻の予定をまとめて作る。
    ///
    /// 他の予定と重なる日は飛ばす。1件も置けない、曜日が空、期間が範囲外のときは nil。
    func createRoutine(
        title: String,
        priority: TaskPriority,
        startDate: Date,
        endDate: Date,
        repeatRule: RoutineRepeat,
        in items: [TimelineItem]
    ) -> Creation? {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, !repeatRule.weekdays.isEmpty else { return nil }

        let startDay = calendar.startOfDay(for: startDate)
        let endDay = calendar.startOfDay(for: repeatRule.endDate)
        guard endDay >= startDay else { return nil }
        let span = calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0
        guard span <= Self.maximumRoutineSpanDays else { return nil }

        let start = DayTime.minutesSinceMidnight(of: startDate, calendar: calendar)
        let endClock = DayTime.minutesSinceMidnight(of: endDate, calendar: calendar)
        guard endClock > start else { return nil }
        let step = Self.createStepMinutes
        let duration = clampDuration(max(step, (endClock - start) / step * step), start: start)

        let routineID = UUID()
        var created: [TimelineItem] = []
        var occupied = items
        var day = startDay
        while day <= endDay {
            let weekday = calendar.component(.weekday, from: day)
            if repeatRule.weekdays.contains(weekday),
               !isOverlapping(start: start, duration: duration, excluding: nil, on: day, in: occupied) {
                let item = TimelineItem(
                    title: title,
                    durationMinutes: duration,
                    startMinutes: start,
                    dropDate: day,
                    priority: priority,
                    routineID: routineID
                )
                created.append(item)
                occupied.append(item)
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        guard let createdItem = created.first else { return nil }

        let routine = TimelineRoutine(
            id: routineID,
            title: title,
            startMinutes: start,
            durationMinutes: duration,
            priority: priority,
            weekdays: RoutineCalendar.orderedWeekdays.filter { repeatRule.weekdays.contains($0) },
            startDate: startDay,
            endDate: endDay
        )
        return Creation(items: items + created, createdItem: createdItem, placement: .timeline, routine: routine)
    }

    /// ルーティン編集の結果。
    struct RoutineRevision: Equatable, Sendable {
        let items: [TimelineItem]
        let routine: TimelineRoutine
    }

    /// ルーティンの型と、まだ紐づいている予定をまとめて更新する。
    ///
    /// 曜日や期間から外れた日は削除する。新しい時刻が他の予定と重なる日は、元の時刻のままルーティンから外す。
    /// 時刻を変えてすでに外れている日は変えない。1件も残らないときは nil。
    func updateRoutine(
        id: UUID,
        title: String,
        priority: TaskPriority,
        startDate: Date,
        endDate: Date,
        repeatRule: RoutineRepeat,
        in items: [TimelineItem]
    ) -> RoutineRevision? {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, !repeatRule.weekdays.isEmpty else { return nil }

        let startDay = calendar.startOfDay(for: startDate)
        let endDay = calendar.startOfDay(for: repeatRule.endDate)
        guard endDay >= startDay else { return nil }
        let span = calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0
        guard span <= Self.maximumRoutineSpanDays else { return nil }

        let start = DayTime.minutesSinceMidnight(of: startDate, calendar: calendar)
        let endClock = DayTime.minutesSinceMidnight(of: endDate, calendar: calendar)
        guard endClock > start else { return nil }
        let step = Self.createStepMinutes
        let duration = clampDuration(max(step, (endClock - start) / step * step), start: start)

        var desiredDays: [Date] = []
        var day = startDay
        while day <= endDay {
            if repeatRule.weekdays.contains(calendar.component(.weekday, from: day)) {
                desiredDays.append(day)
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        guard !desiredDays.isEmpty else { return nil }

        var kept: [TimelineItem] = []
        var linkedByDay: [Date: TimelineItem] = [:]
        for item in items {
            guard item.routineID == id, let dropDate = item.dropDate else {
                var detached = item
                if item.routineID == id {
                    detached.routineID = nil
                }
                kept.append(detached)
                continue
            }
            let itemDay = calendar.startOfDay(for: dropDate)
            if linkedByDay[itemDay] == nil {
                linkedByDay[itemDay] = item
            } else {
                var detached = item
                detached.routineID = nil
                kept.append(detached)
            }
        }

        var occupied = kept
        var seriesItems: [TimelineItem] = []
        for day in desiredDays {
            if var existing = linkedByDay[day] {
                if isOverlapping(start: start, duration: duration, excluding: existing.id, on: day, in: occupied) {
                    existing.routineID = nil
                    kept.append(existing)
                    occupied.append(existing)
                } else {
                    existing.title = title
                    existing.startMinutes = start
                    existing.durationMinutes = duration
                    existing.priority = priority
                    existing.dropDate = day
                    seriesItems.append(existing)
                    occupied.append(existing)
                }
            } else if !isOverlapping(start: start, duration: duration, excluding: nil, on: day, in: occupied) {
                let item = TimelineItem(
                    title: title,
                    durationMinutes: duration,
                    startMinutes: start,
                    dropDate: day,
                    priority: priority,
                    routineID: id
                )
                seriesItems.append(item)
                occupied.append(item)
            }
        }
        guard !seriesItems.isEmpty else { return nil }

        let routine = TimelineRoutine(
            id: id,
            title: title,
            startMinutes: start,
            durationMinutes: duration,
            priority: priority,
            weekdays: RoutineCalendar.orderedWeekdays.filter { repeatRule.weekdays.contains($0) },
            startDate: startDay,
            endDate: endDay
        )
        return RoutineRevision(items: kept + seriesItems, routine: routine)
    }

    /// 仮配置を、タイトルを付けて予定として確定する。タイトルが空の場合は nil。
    func confirm(_ pending: PendingPlacement, title: String, in items: [TimelineItem]) -> Creation? {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }

        let newItem = TimelineItem(
            title: title,
            durationMinutes: pending.durationMinutes,
            startMinutes: pending.startMinutes,
            dropDate: pending.date
        )
        return Creation(items: items + [newItem], createdItem: newItem, placement: .timeline, routine: nil)
    }

    // MARK: - 更新

    /// タイトルだけを変える。空のタイトル・変更なしの場合は nil。
    func rename(itemID: UUID, title: String, in items: [TimelineItem]) -> [TimelineItem]? {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty,
              let index = items.firstIndex(where: { $0.id == itemID }),
              items[index].title != title
        else { return nil }

        var updated = items
        updated[index].title = title
        return updated
    }

    /// タイトル・所要時間・優先度をまとめて変える。
    func update(
        itemID: UUID,
        title: String,
        durationMinutes: Int,
        priority: TaskPriority,
        in items: [TimelineItem]
    ) -> [TimelineItem]? {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, let index = items.firstIndex(where: { $0.id == itemID }) else { return nil }

        let current = items[index]
        let duration = clampDuration(durationMinutes, start: current.startMinutes ?? 0)
        if let start = current.startMinutes, let date = current.dropDate {
            guard !isOverlapping(start: start, duration: duration, excluding: itemID, on: date, in: items) else {
                return nil
            }
        }

        var updated = items
        applyScheduleChange(
            to: &updated[index],
            startMinutes: current.startMinutes,
            dropDate: current.dropDate,
            durationMinutes: duration
        )
        updated[index].title = title
        updated[index].priority = priority
        return updated
    }

    /// 開始時刻・日付・長さが変わった予定はルーティンから外す。タイトルや優先度だけなら紐づけを残す。
    private func applyScheduleChange(
        to item: inout TimelineItem,
        startMinutes: Int?,
        dropDate: Date?,
        durationMinutes: Int
    ) {
        let dayChanged: Bool
        switch (item.dropDate, dropDate) {
        case (nil, nil):
            dayChanged = false
        case let (current?, updated?):
            dayChanged = !calendar.isDate(current, inSameDayAs: updated)
        default:
            dayChanged = true
        }
        if item.startMinutes != startMinutes || dayChanged || item.durationMinutes != durationMinutes {
            item.routineID = nil
        }
        item.startMinutes = startMinutes
        item.dropDate = dropDate
        item.durationMinutes = durationMinutes
    }

    /// Stock 内の並び順を変える。配置済みの予定は Stock の後ろにまとめる。
    /// - Parameters:
    ///   - fromIndex: 動かすタスクの、Stock 内での位置
    ///   - toOffset: 挿入先（動かす前の並びで数えた位置。末尾は Stock の件数）
    func moveStockItem(fromIndex: Int, toOffset: Int, in items: [TimelineItem]) -> [TimelineItem]? {
        var stock = items.filter(\.isInStock)
        let placed = items.filter { !$0.isInStock }
        guard stock.indices.contains(fromIndex) else { return nil }

        let destination = min(toOffset, stock.count)
        let moved = stock.remove(at: fromIndex)
        stock.insert(moved, at: destination > fromIndex ? destination - 1 : destination)
        return stock + placed
    }

    // MARK: - 判定・丸め

    /// 指定した時間帯が、同じ日の他の予定と重なるか。
    func isOverlapping(
        start: Int,
        duration: Int,
        excluding excludedID: UUID?,
        on date: Date,
        in items: [TimelineItem]
    ) -> Bool {
        let end = start + duration
        return items.contains { item in
            guard item.id != excludedID,
                  let itemStart = item.startMinutes,
                  item.isPlaced(on: date, calendar: calendar)
            else { return false }
            return start < itemStart + item.durationMinutes && end > itemStart
        }
    }

    private func startMinutes(forDropAt rawMinutes: Int, durationMinutes: Int) -> Int {
        clampStart(snap(rawMinutes, step: Self.dropStepMinutes), durationMinutes: durationMinutes)
    }

    private func resizedDuration(of item: TimelineItem, deltaMinutes: Int) -> Int {
        clampDuration(
            snap(item.durationMinutes + deltaMinutes, step: Self.resizeStepMinutes),
            start: item.startMinutes ?? 0
        )
    }

    /// `step` 分刻みの近い方へ丸める（ちょうど中間は切り上げ）。
    private func snap(_ minutes: Int, step: Int) -> Int {
        let lower = minutes - minutes % step
        let upper = lower + step
        return (minutes - lower) < (upper - minutes) ? lower : upper
    }

    /// 予定がその日のうちに収まるよう、開始時刻を 0 時〜（24 時 − 所要時間）に収める。
    private func clampStart(_ start: Int, durationMinutes: Int) -> Int {
        let latestStart = max(0, DayTime.minutesPerDay - durationMinutes)
        return max(0, min(latestStart, start))
    }

    /// 所要時間を、最短時間〜その日の終わりまでに収める。
    private func clampDuration(_ duration: Int, start: Int) -> Int {
        let longest = max(Self.minimumDurationMinutes, DayTime.minutesPerDay - start)
        return max(Self.minimumDurationMinutes, min(longest, duration))
    }
}
