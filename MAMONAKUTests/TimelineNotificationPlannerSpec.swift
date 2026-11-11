import Foundation
import Quick
import Nimble
@testable import MAMONAKU

final class TimelineNotificationPlannerSpec: QuickSpec {
    override class func spec() {
        let now = TestTime.date(hour: 9)

        func plans(
            _ kind: TimelineNotificationKind,
            items: [TimelineItem],
            isPlusSubscriber: Bool = true,
            bufferMinutes: Int = 10
        ) -> [TimelineNotificationPlan] {
            TimelineNotificationPlanner.plans(
                kind: kind,
                items: items,
                now: now,
                isPlusSubscriber: isPlusSubscriber,
                bufferMinutes: bufferMinutes,
                calendar: TestTime.calendar
            )
        }

        describe("開始通知") {
            it("これから始まる予定だけを、開始時刻の早い順に登録する") {
                let items: [TimelineItem] = [
                    .placed("午後", startMinutes: 780),
                    .placed("開始済み", startMinutes: 480),
                    .placed("次", startMinutes: 570),
                    .placed("終日", startMinutes: 600, isAllDay: true),
                    .stock("未配置")
                ]

                let result = plans(.start, items: items)

                expect(result.map(\.body)).to(equal(["「次」を開始しましょう", "「午後」を開始しましょう"]))
                expect(result.first?.fireDate).to(equal(TestTime.date(hour: 9, minute: 30)))
                expect(result.first?.title).to(equal("予定の開始時間です"))
            }

            it("通知 ID は種類ごとの接頭辞と予定 ID で作る") {
                let item = TimelineItem.placed("次", startMinutes: 570)

                let result = plans(.start, items: [item])

                expect(result.first?.identifier).to(equal("timeline.start.notification.\(item.id.uuidString)"))
            }

            it("無料プランでは直近の 1 件だけ登録する") {
                let items: [TimelineItem] = [.placed("午後", startMinutes: 780), .placed("次", startMinutes: 570)]

                let result = plans(.start, items: items, isPlusSubscriber: false)

                expect(result.map(\.body)).to(equal(["「次」を開始しましょう"]))
            }

            it("登録は 60 件までにする") {
                let items = (0..<70).map { TimelineItem.placed("予定\($0)", startMinutes: 600 + $0 * 5) }

                expect(plans(.start, items: items).count).to(equal(60))
            }
        }

        describe("バッファ通知") {
            it("開始のバッファ分前に届くようにする") {
                let item = TimelineItem.placed("会議", startMinutes: 600)

                let result = plans(.buffer, items: [item], bufferMinutes: 15)

                expect(result.first?.fireDate).to(equal(TestTime.date(hour: 9, minute: 45)))
                expect(result.first?.title).to(equal("まもなく開始"))
                expect(result.first?.body).to(equal("まもなく「会議」です。準備をしましょう"))
                expect(result.first?.identifier).to(equal("timeline.buffer.notification.\(item.id.uuidString)"))
            }

            it("通知時刻をすでに過ぎている予定は登録しない") {
                let item = TimelineItem.placed("すぐ始まる", startMinutes: 550)

                expect(plans(.buffer, items: [item], bufferMinutes: 15)).to(beEmpty())
            }

            it("無料プランの 1 件制限は開始通知だけに適用する") {
                let items: [TimelineItem] = [.placed("A", startMinutes: 600), .placed("B", startMinutes: 700)]

                expect(plans(.buffer, items: items, isPlusSubscriber: false).count).to(equal(2))
            }
        }

        describe("TimelineNotificationKind.owns") {
            it("自分の種類の通知と、旧バージョンが登録した通知を自分のものとして扱う") {
                expect(TimelineNotificationKind.start.owns(identifier: "timeline.start.notification.X")).to(beTrue())
                expect(TimelineNotificationKind.start.owns(identifier: "liveActivity.start.notification.X")).to(beTrue())
                expect(TimelineNotificationKind.buffer.owns(identifier: "timeline.buffer.notification.X")).to(beTrue())
                expect(TimelineNotificationKind.buffer.owns(identifier: "liveActivity.soon.notification")).to(beTrue())
            }

            it("別の種類の通知は自分のものとして扱わない") {
                expect(TimelineNotificationKind.start.owns(identifier: "timeline.buffer.notification.X")).to(beFalse())
                expect(TimelineNotificationKind.buffer.owns(identifier: "timeline.start.notification.X")).to(beFalse())
            }
        }
    }
}
