import Foundation
import Quick
import Nimble
@testable import MAMONAKU

final class LiveActivityScheduleBuilderSpec: QuickSpec {
    override class func spec() {
        /// 10:00 / 11:00 / 12:00 / 13:00 開始の 4 件（各 30 分）
        let items: [TimelineItem] = [
            .placed("C", startMinutes: 720),
            .placed("A", startMinutes: 600),
            .placed("D", startMinutes: 780),
            .placed("B", startMinutes: 660)
        ]
        let entries = LiveActivityScheduleBuilder.entriesForToday(
            items: items,
            referenceDate: TestTime.date(hour: 9),
            calendar: TestTime.calendar
        )

        describe("entriesForToday") {
            it("当日に配置された予定を開始時刻順に並べる") {
                expect(entries.map(\.item.title)).to(equal(["A", "B", "C", "D"]))
                expect(entries.first?.startDate).to(equal(TestTime.date(hour: 10)))
                expect(entries.first?.endDate).to(equal(TestTime.date(hour: 10, minute: 30)))
            }

            it("別の日の予定・終日予定・Stock のタスクは含めない") {
                let mixed: [TimelineItem] = [
                    .placed("今日", startMinutes: 600),
                    .placed("翌日", startMinutes: 600, on: TestTime.tomorrow),
                    .placed("終日", startMinutes: 0, isAllDay: true),
                    .stock("未配置")
                ]

                let result = LiveActivityScheduleBuilder.entriesForToday(
                    items: mixed,
                    referenceDate: TestTime.date(hour: 9),
                    calendar: TestTime.calendar
                )

                expect(result.map(\.item.title)).to(equal(["今日"]))
            }
        }

        describe("currentWindow") {
            it("PLUS は、まだ始まっていない予定を先頭から最大 3 件表示する") {
                let result = LiveActivityScheduleBuilder.currentWindow(
                    entries: entries, now: TestTime.date(hour: 10, minute: 30), planScope: .plus
                )

                expect(result.startIndex).to(equal(1))
                expect(result.window.map(\.item.title)).to(equal(["B", "C", "D"]))
            }

            it("無料は、まだ始まっていない最初の 1 件だけ表示する") {
                let result = LiveActivityScheduleBuilder.currentWindow(
                    entries: entries, now: TestTime.date(hour: 10, minute: 30), planScope: .free
                )

                expect(result.window.map(\.item.title)).to(equal(["B"]))
            }

            it("すべての予定が始まった後は何も表示しない") {
                let result = LiveActivityScheduleBuilder.currentWindow(
                    entries: entries, now: TestTime.date(hour: 14), planScope: .plus
                )

                expect(result.window).to(beEmpty())
            }
        }

        describe("buildTaskItems") {
            it("先頭の予定だけがカウントダウン対象になり、以降は開始までの時間を表示する") {
                let now = TestTime.date(hour: 9, minute: 30)

                let schedule = LiveActivityScheduleBuilder.buildTaskItems(
                    from: entries[0..<2], now: now, bufferMinutes: { _ in 10 }
                )

                expect(schedule[0].nextTitle).to(equal("A"))
                expect(schedule[0].nextStartDate).to(equal(TestTime.date(hour: 10)))
                expect(schedule[0].nextEndDate).to(equal(TestTime.date(hour: 10, minute: 30)))
                expect(schedule[0].countdownStartDate).to(equal(now))
                expect(schedule[0].remainingTimeShort).to(equal("30:00"))
                expect(schedule[0].bufferMinutes).to(equal(10))

                expect(schedule[1].nextTitle).to(equal("B"))
                expect(schedule[1].nextEndDate).to(beNil())
                expect(schedule[1].countdownStartDate).to(beNil())
                expect(schedule[1].remainingTimeShort).to(equal("90分後"))
            }
        }

        describe("buildRotations") {
            let now = TestTime.date(hour: 9, minute: 30)

            it("各予定の開始時刻に、次の予定から始まる表示へ切り替える") {
                let rotations = LiveActivityScheduleBuilder.buildRotations(
                    entries: entries, startIndex: 0, now: now, planScope: .plus, bufferMinutes: { _ in nil }
                )

                expect(rotations.map(\.switchAt)).to(equal(entries.map(\.startDate)))
                expect(rotations[0].schedule.map(\.nextTitle)).to(equal(["B", "C", "D"]))
                expect(rotations[1].schedule.map(\.nextTitle)).to(equal(["C", "D"]))
                expect(rotations[0].shouldEndActivity).to(beFalse())
            }

            it("最後の予定が始まったら Live Activity を終了する") {
                let rotations = LiveActivityScheduleBuilder.buildRotations(
                    entries: entries, startIndex: 0, now: now, planScope: .plus, bufferMinutes: { _ in nil }
                )

                expect(rotations.last?.shouldEndActivity).to(beTrue())
                expect(rotations.last?.schedule).to(beEmpty())
            }

            it("無料は切り替え後も 1 件だけ表示する") {
                let rotations = LiveActivityScheduleBuilder.buildRotations(
                    entries: entries, startIndex: 0, now: now, planScope: .free, bufferMinutes: { _ in nil }
                )

                expect(rotations[0].schedule.map(\.nextTitle)).to(equal(["B"]))
            }

            it("すでに始まった予定への切り替えは予約しない") {
                let rotations = LiveActivityScheduleBuilder.buildRotations(
                    entries: entries,
                    startIndex: 0,
                    now: TestTime.date(hour: 11, minute: 30),
                    planScope: .plus,
                    bufferMinutes: { _ in nil }
                )

                expect(rotations.map(\.switchAt)).to(equal([TestTime.date(hour: 12), TestTime.date(hour: 13)]))
            }
        }
    }
}
