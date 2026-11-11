import Foundation
import Quick
import Nimble
@testable import MAMONAKU

final class DayTimeSpec: QuickSpec {
    override class func spec() {
        describe("DayTime") {
            it("0 時からの経過分を HH:mm で表示する") {
                expect(DayTime.clockText(minutes: 0)).to(equal("00:00"))
                expect(DayTime.clockText(minutes: 545)).to(equal("09:05"))
            }

            it("24 時は 00:00 に折り返して表示する") {
                expect(DayTime.clockText(minutes: 1440)).to(equal("00:00"))
            }

            it("開始〜終了を範囲で表示する") {
                expect(DayTime.rangeText(startMinutes: 540, durationMinutes: 90)).to(equal("09:00 - 10:30"))
            }

            it("日時から 0 時からの経過分・秒を求める") {
                let date = TestTime.date(hour: 9, minute: 5, second: 30)

                expect(DayTime.minutesSinceMidnight(of: date, calendar: TestTime.calendar)).to(equal(545))
                expect(DayTime.secondsSinceMidnight(of: date, calendar: TestTime.calendar)).to(equal(32_730))
            }
        }

        describe("[TimelineItem].nextItem(after:)") {
            it("同じ日の、まだ始まっていない予定のうち最も早いものを返す") {
                let items: [TimelineItem] = [
                    .placed("午後", startMinutes: 780),
                    .placed("開始済み", startMinutes: 480),
                    .placed("次", startMinutes: 600),
                    .placed("翌日", startMinutes: 550, on: TestTime.tomorrow),
                    .stock("未配置")
                ]

                let next = items.nextItem(after: TestTime.date(hour: 9), calendar: TestTime.calendar)

                expect(next?.title).to(equal("次"))
            }

            it("開始まで 1 分を切っていても、まだ始まっていなければ次の予定として扱う") {
                let items: [TimelineItem] = [.placed("まもなく", startMinutes: 541)]

                let next = items.nextItem(
                    after: TestTime.date(hour: 9, minute: 0, second: 30),
                    calendar: TestTime.calendar
                )

                expect(next?.title).to(equal("まもなく"))
            }

            it("ちょうど開始時刻になった予定は次の予定に含めない") {
                let items: [TimelineItem] = [.placed("開始", startMinutes: 540)]

                let next = items.nextItem(after: TestTime.date(hour: 9), calendar: TestTime.calendar)

                expect(next).to(beNil())
            }
        }
    }
}
