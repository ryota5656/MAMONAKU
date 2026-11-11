import Foundation
import Quick
import Nimble
@testable import MAMONAKU

final class TimelineItemEditUseCaseSpec: QuickSpec {
    override class func spec() {
        let useCase = TimelineItemEditUseCase(calendar: TestTime.calendar)
        let today = TestTime.today

        describe("place（ドロップによる配置・移動）") {
            it("ドロップ位置を 5 分刻みに丸めて配置する") {
                let task = TimelineItem.stock("資料作成")

                let down = useCase.place(itemID: task.id, atMinutes: 542, on: today, in: [task])
                let up = useCase.place(itemID: task.id, atMinutes: 543, on: today, in: [task])

                expect(down?.first?.startMinutes).to(equal(540))
                expect(up?.first?.startMinutes).to(equal(545))
                expect(down?.first?.dropDate).to(equal(today))
            }

            it("予定が 24 時をまたがないよう開始時刻を繰り上げる") {
                let task = TimelineItem.stock("長い作業", durationMinutes: 60)

                let result = useCase.place(itemID: task.id, atMinutes: 1430, on: today, in: [task])

                expect(result?.first?.startMinutes).to(equal(1380))
            }

            it("同じ日の他の予定と重なる位置には置けない") {
                let existing = TimelineItem.placed("会議", startMinutes: 600, durationMinutes: 60)
                let task = TimelineItem.stock("資料作成")

                let result = useCase.place(itemID: task.id, atMinutes: 630, on: today, in: [existing, task])

                expect(result).to(beNil())
            }

            it("直前の予定の終了時刻ちょうどには置ける") {
                let existing = TimelineItem.placed("会議", startMinutes: 600, durationMinutes: 60)
                let task = TimelineItem.stock("資料作成")

                let result = useCase.place(itemID: task.id, atMinutes: 660, on: today, in: [existing, task])

                expect(result?.last?.startMinutes).to(equal(660))
            }

            it("別の日の予定とは重なりを判定しない") {
                let existing = TimelineItem.placed("会議", startMinutes: 600, durationMinutes: 60)
                let task = TimelineItem.stock("資料作成")

                let result = useCase.place(itemID: task.id, atMinutes: 600, on: TestTime.tomorrow, in: [existing, task])

                expect(result?.last?.dropDate).to(equal(TestTime.tomorrow))
            }

            it("配置済みの予定は、自分の元の時間帯と重なる位置へも動かせる") {
                let item = TimelineItem.placed("会議", startMinutes: 600, durationMinutes: 60)

                let result = useCase.place(itemID: item.id, atMinutes: 615, on: today, in: [item])

                expect(result?.first?.startMinutes).to(equal(615))
            }
        }

        describe("returnToStock") {
            it("配置済みの予定から日付と開始時刻を外す") {
                let item = TimelineItem.placed("会議", startMinutes: 600)

                let result = useCase.returnToStock(itemID: item.id, in: [item])

                expect(result?.first?.isInStock).to(beTrue())
                expect(result?.first?.startMinutes).to(beNil())
            }
        }

        describe("resize") {
            it("所要時間を 5 分刻みで伸縮する") {
                let item = TimelineItem.placed("会議", startMinutes: 600, durationMinutes: 30)

                let result = useCase.resize(itemID: item.id, deltaMinutes: 17, fallbackDate: today, in: [item])

                expect(result?.first?.durationMinutes).to(equal(45))
            }

            it("15 分より短くはできない") {
                let item = TimelineItem.placed("会議", startMinutes: 600, durationMinutes: 30)

                let result = useCase.resize(itemID: item.id, deltaMinutes: -60, fallbackDate: today, in: [item])

                expect(result?.first?.durationMinutes).to(equal(15))
            }

            it("24 時を超える長さにはできない") {
                let item = TimelineItem.placed("夜の作業", startMinutes: 1380, durationMinutes: 30)

                let result = useCase.resize(itemID: item.id, deltaMinutes: 120, fallbackDate: today, in: [item])

                expect(result?.first?.durationMinutes).to(equal(60))
            }

            it("後ろの予定と重なる長さには伸ばせない") {
                let item = TimelineItem.placed("会議", startMinutes: 600, durationMinutes: 30)
                let next = TimelineItem.placed("昼食", startMinutes: 660, durationMinutes: 30)

                let result = useCase.resize(itemID: item.id, deltaMinutes: 60, fallbackDate: today, in: [item, next])

                expect(result).to(beNil())
            }

            it("Stock のタスクはリサイズできない") {
                let task = TimelineItem.stock("資料作成")

                expect(useCase.resize(itemID: task.id, deltaMinutes: 30, fallbackDate: today, in: [task])).to(beNil())
                expect(useCase.resizePreview(of: task, deltaMinutes: 30, fallbackDate: today)).to(beNil())
            }
        }

        describe("長押しによる仮配置") {
            it("長押しした位置から 30 分の仮配置を作る") {
                let pending = useCase.beginPendingPlacement(atMinutes: 602, on: today, in: [])

                expect(pending).to(equal(
                    PendingPlacement(date: today, startMinutes: 600, durationMinutes: 30, isAwaitingTitle: false)
                ))
            }

            it("後続の予定までの空きが 30 分に足りなければ、その手前までに縮める") {
                let next = TimelineItem.placed("会議", startMinutes: 620)

                let pending = useCase.beginPendingPlacement(atMinutes: 600, on: today, in: [next])

                expect(pending?.durationMinutes).to(equal(20))
            }

            it("既存の予定の上では仮配置を作らない") {
                let existing = TimelineItem.placed("会議", startMinutes: 600, durationMinutes: 60)

                let pending = useCase.beginPendingPlacement(atMinutes: 610, on: today, in: [existing])

                expect(pending).to(beNil())
            }

            it("指を下へ動かすと、開始時刻はそのままで長さが伸びる") {
                let pending = PendingPlacement(date: today, startMinutes: 600, durationMinutes: 30, isAwaitingTitle: false)

                let extended = useCase.extendPendingPlacement(pending, toMinutes: 691, in: [])

                expect(extended.startMinutes).to(equal(600))
                expect(extended.durationMinutes).to(equal(90))
            }

            it("後続の予定を越えては伸びない") {
                let pending = PendingPlacement(date: today, startMinutes: 600, durationMinutes: 30, isAwaitingTitle: false)
                let next = TimelineItem.placed("会議", startMinutes: 660)

                let extended = useCase.extendPendingPlacement(pending, toMinutes: 720, in: [next])

                expect(extended.durationMinutes).to(equal(60))
            }

            it("タイトルを付けると、仮配置の位置に予定を作る") {
                let pending = PendingPlacement(date: today, startMinutes: 600, durationMinutes: 45, isAwaitingTitle: true)

                let creation = useCase.confirm(pending, title: "  打ち合わせ  ", in: [])

                expect(creation?.createdItem.title).to(equal("打ち合わせ"))
                expect(creation?.createdItem.startMinutes).to(equal(600))
                expect(creation?.createdItem.durationMinutes).to(equal(45))
                expect(creation?.createdItem.dropDate).to(equal(today))
                expect(creation?.placement).to(equal(.timeline))
            }

            it("タイトルが空なら予定を作らない") {
                let pending = PendingPlacement(date: today, startMinutes: 600, durationMinutes: 45, isAwaitingTitle: true)

                expect(useCase.confirm(pending, title: "   ", in: [])).to(beNil())
            }
        }

        describe("create") {
            it("日時の指定が無ければ Stock に追加する") {
                let creation = useCase.create(
                    title: "資料作成", durationMinutes: 45, priority: .high, startDate: nil, endDate: nil, in: []
                )

                expect(creation?.placement).to(equal(.stock))
                expect(creation?.createdItem.isInStock).to(beTrue())
                expect(creation?.createdItem.durationMinutes).to(equal(45))
                expect(creation?.createdItem.priority).to(equal(.high))
                expect(creation?.items.count).to(equal(1))
            }

            it("開始・終了の指定があればタイムラインに配置し、所要時間を 5 分単位に切り捨てる") {
                let creation = useCase.create(
                    title: "会議",
                    durationMinutes: 30,
                    priority: .low,
                    startDate: TestTime.date(hour: 10),
                    endDate: TestTime.date(hour: 10, minute: 52),
                    in: []
                )

                expect(creation?.placement).to(equal(.timeline))
                expect(creation?.createdItem.startMinutes).to(equal(600))
                expect(creation?.createdItem.durationMinutes).to(equal(50))
                expect(creation?.createdItem.dropDate).to(equal(today))
            }

            it("指定した時間帯が他の予定と重なる場合は Stock に追加する") {
                let existing = TimelineItem.placed("会議", startMinutes: 600, durationMinutes: 60)

                let creation = useCase.create(
                    title: "資料作成",
                    durationMinutes: 30,
                    priority: .low,
                    startDate: TestTime.date(hour: 10, minute: 30),
                    endDate: TestTime.date(hour: 11, minute: 30),
                    in: [existing]
                )

                expect(creation?.placement).to(equal(.stock))
                expect(creation?.createdItem.isInStock).to(beTrue())
            }

            it("タイトルが空なら作らない") {
                let creation = useCase.create(
                    title: " \n", durationMinutes: 30, priority: .low, startDate: nil, endDate: nil, in: []
                )

                expect(creation).to(beNil())
            }
        }

        describe("createRoutine") {
            let thursday = TestTime.calendar.component(.weekday, from: today)
            let friday = TestTime.calendar.component(.weekday, from: TestTime.tomorrow)

            it("選んだ曜日の開始日から終了日まで、同じ時刻で作る") {
                let creation = useCase.createRoutine(
                    title: "バイト",
                    priority: .medium,
                    startDate: TestTime.date(hour: 10),
                    endDate: TestTime.date(hour: 13),
                    repeatRule: RoutineRepeat(weekdays: [thursday, friday], endDate: TestTime.tomorrow),
                    in: []
                )

                expect(creation?.routine?.weekdaySet).to(equal(Set([thursday, friday])))
                expect(creation?.items.map(\.dropDate)).to(equal([today, TestTime.tomorrow]))
                expect(creation?.items.map(\.startMinutes)).to(equal([600, 600]))
                expect(creation?.items.map(\.durationMinutes)).to(equal([180, 180]))
                expect(creation?.items.map(\.routineID)).to(equal([creation?.routine?.id, creation?.routine?.id]))
            }

            it("他の予定と重なる日は飛ばす") {
                let existing = TimelineItem.placed("会議", startMinutes: 600, durationMinutes: 60)

                let creation = useCase.createRoutine(
                    title: "バイト",
                    priority: .low,
                    startDate: TestTime.date(hour: 10),
                    endDate: TestTime.date(hour: 12),
                    repeatRule: RoutineRepeat(weekdays: [thursday, friday], endDate: TestTime.tomorrow),
                    in: [existing]
                )

                expect(creation?.items.map(\.dropDate)).to(equal([existing.dropDate, TestTime.tomorrow]))
                expect(creation?.items.filter { $0.routineID != nil }.map(\.dropDate)).to(equal([TestTime.tomorrow]))
            }

            it("1件も置けないときは作らない") {
                let existing = TimelineItem.placed("会議", startMinutes: 600, durationMinutes: 180)

                let creation = useCase.createRoutine(
                    title: "バイト",
                    priority: .low,
                    startDate: TestTime.date(hour: 10),
                    endDate: TestTime.date(hour: 12),
                    repeatRule: RoutineRepeat(weekdays: [thursday], endDate: today),
                    in: [existing]
                )

                expect(creation).to(beNil())
            }
        }

        describe("updateRoutine") {
            let routineID = UUID()
            let thursday = TestTime.calendar.component(.weekday, from: today)
            let friday = TestTime.calendar.component(.weekday, from: TestTime.tomorrow)

            func linked(
                _ title: String = "バイト",
                startMinutes: Int = 600,
                durationMinutes: Int = 120,
                on date: Date = TestTime.today,
                isCompleted: Bool = false
            ) -> TimelineItem {
                var item = TimelineItem.placed(title, startMinutes: startMinutes, durationMinutes: durationMinutes, on: date)
                item.routineID = routineID
                item.isCompleted = isCompleted
                return item
            }

            it("タイトルと時刻を、まだ紐づいている予定へ反映する") {
                let todayItem = linked(isCompleted: true)
                let tomorrowItem = linked(on: TestTime.tomorrow)

                let revision = useCase.updateRoutine(
                    id: routineID,
                    title: "夕方バイト",
                    priority: .high,
                    startDate: TestTime.date(hour: 18),
                    endDate: TestTime.date(hour: 21),
                    repeatRule: RoutineRepeat(weekdays: [thursday, friday], endDate: TestTime.tomorrow),
                    in: [todayItem, tomorrowItem]
                )

                let updated = revision?.items.filter { $0.routineID == routineID }
                expect(updated?.map(\.id)).to(equal([todayItem.id, tomorrowItem.id]))
                expect(updated?.map(\.title)).to(equal(["夕方バイト", "夕方バイト"]))
                expect(updated?.map(\.startMinutes)).to(equal([18 * 60, 18 * 60]))
                expect(updated?.map(\.durationMinutes)).to(equal([180, 180]))
                expect(updated?.first?.isCompleted).to(beTrue())
                expect(revision?.routine.title).to(equal("夕方バイト"))
            }

            it("曜日から外した日は削除し、すでに外れている日は残す") {
                let todayItem = linked()
                let tomorrowItem = linked(on: TestTime.tomorrow)
                var detached = TimelineItem.placed("振替", startMinutes: 900, on: TestTime.tomorrow)
                detached.routineID = nil

                let revision = useCase.updateRoutine(
                    id: routineID,
                    title: "バイト",
                    priority: .medium,
                    startDate: TestTime.date(hour: 10),
                    endDate: TestTime.date(hour: 12),
                    repeatRule: RoutineRepeat(weekdays: [thursday], endDate: today),
                    in: [todayItem, tomorrowItem, detached]
                )

                expect(revision?.items.map(\.id)).to(equal([detached.id, todayItem.id]))
                expect(revision?.items.first { $0.id == todayItem.id }?.routineID).to(equal(routineID))
            }

            it("期間を延ばすと、空いている日を追加する") {
                let todayItem = linked()

                let revision = useCase.updateRoutine(
                    id: routineID,
                    title: "バイト",
                    priority: .low,
                    startDate: TestTime.date(hour: 10),
                    endDate: TestTime.date(hour: 12),
                    repeatRule: RoutineRepeat(weekdays: [thursday, friday], endDate: TestTime.tomorrow),
                    in: [todayItem]
                )

                let days = revision?.items.filter { $0.routineID == routineID }.map(\.dropDate)
                expect(days).to(equal([today, TestTime.tomorrow]))
                expect(revision?.items.first { $0.id == todayItem.id }).notTo(beNil())
            }

            it("新しい時刻が重なる日は元の時刻のまま外し、全部重なるときは保存しない") {
                let todayItem = linked()
                let tomorrowItem = linked(on: TestTime.tomorrow)
                let conflict = TimelineItem.placed("会議", startMinutes: 18 * 60, durationMinutes: 60)

                let partial = useCase.updateRoutine(
                    id: routineID,
                    title: "バイト",
                    priority: .low,
                    startDate: TestTime.date(hour: 18),
                    endDate: TestTime.date(hour: 19),
                    repeatRule: RoutineRepeat(weekdays: [thursday, friday], endDate: TestTime.tomorrow),
                    in: [conflict, todayItem, tomorrowItem]
                )

                expect(partial?.items.first { $0.id == todayItem.id }?.routineID).to(beNil())
                expect(partial?.items.first { $0.id == todayItem.id }?.startMinutes).to(equal(600))
                expect(partial?.items.first { $0.id == tomorrowItem.id }?.startMinutes).to(equal(18 * 60))

                let blocked = useCase.updateRoutine(
                    id: routineID,
                    title: "バイト",
                    priority: .low,
                    startDate: TestTime.date(hour: 18),
                    endDate: TestTime.date(hour: 19),
                    repeatRule: RoutineRepeat(weekdays: [thursday], endDate: today),
                    in: [conflict, todayItem]
                )
                expect(blocked).to(beNil())
            }
        }

        describe("ルーティンからの切り離し") {
            let routineID = UUID()

            func linked(_ title: String = "バイト") -> TimelineItem {
                var item = TimelineItem.placed(title, startMinutes: 600, durationMinutes: 120)
                item.routineID = routineID
                return item
            }

            it("同じ位置に置き直してもルーティンに残す") {
                let item = linked()

                let result = useCase.place(itemID: item.id, atMinutes: 600, on: today, in: [item])

                expect(result?.first?.routineID).to(equal(routineID))
            }

            it("時刻をずらすとルーティンから外す") {
                let item = linked()

                let result = useCase.place(itemID: item.id, atMinutes: 630, on: today, in: [item])

                expect(result?.first?.startMinutes).to(equal(630))
                expect(result?.first?.routineID).to(beNil())
            }

            it("長さを変えるとルーティンから外す") {
                let item = linked()

                let result = useCase.resize(itemID: item.id, deltaMinutes: 30, fallbackDate: today, in: [item])

                expect(result?.first?.durationMinutes).to(equal(150))
                expect(result?.first?.routineID).to(beNil())
            }

            it("タイトルだけ変えてもルーティンに残す") {
                let item = linked()

                let result = useCase.update(
                    itemID: item.id, title: "バイト（振替）", durationMinutes: 120, priority: .high, in: [item]
                )

                expect(result?.first?.title).to(equal("バイト（振替）"))
                expect(result?.first?.routineID).to(equal(routineID))
            }

            it("Stock に戻すとルーティンから外す") {
                let item = linked()

                let result = useCase.returnToStock(itemID: item.id, in: [item])

                expect(result?.first?.isInStock).to(beTrue())
                expect(result?.first?.routineID).to(beNil())
            }
        }

        describe("rename / update") {
            it("前後の空白を除いたタイトルに変える") {
                let item = TimelineItem.placed("会議", startMinutes: 600)

                let result = useCase.rename(itemID: item.id, title: " 定例会議 ", in: [item])

                expect(result?.first?.title).to(equal("定例会議"))
            }

            it("空のタイトル・同じタイトルへの変更は行わない") {
                let item = TimelineItem.placed("会議", startMinutes: 600)

                expect(useCase.rename(itemID: item.id, title: "", in: [item])).to(beNil())
                expect(useCase.rename(itemID: item.id, title: "会議", in: [item])).to(beNil())
            }

            it("タイトル・所要時間・優先度をまとめて変える") {
                let task = TimelineItem.stock("資料作成")

                let result = useCase.update(
                    itemID: task.id, title: "資料レビュー", durationMinutes: 90, priority: .high, in: [task]
                )

                expect(result?.first?.title).to(equal("資料レビュー"))
                expect(result?.first?.durationMinutes).to(equal(90))
                expect(result?.first?.priority).to(equal(.high))
            }

            it("所要時間は最短 15 分にする") {
                let task = TimelineItem.stock("資料作成")

                let result = useCase.update(
                    itemID: task.id, title: "資料作成", durationMinutes: 5, priority: .low, in: [task]
                )

                expect(result?.first?.durationMinutes).to(equal(15))
            }

            it("配置済みの予定を、後ろの予定と重なる長さには変えられない") {
                let item = TimelineItem.placed("会議", startMinutes: 600, durationMinutes: 30)
                let next = TimelineItem.placed("昼食", startMinutes: 660)

                let result = useCase.update(
                    itemID: item.id, title: "会議", durationMinutes: 90, priority: .low, in: [item, next]
                )

                expect(result).to(beNil())
            }
        }

        describe("moveStockItem") {
            let first = TimelineItem.stock("A")
            let second = TimelineItem.stock("B")
            let third = TimelineItem.stock("C")
            let placed = TimelineItem.placed("会議", startMinutes: 600)

            it("Stock の先頭のタスクを末尾へ動かす") {
                let result = useCase.moveStockItem(fromIndex: 0, toOffset: 3, in: [first, second, third])

                expect(result?.map(\.title)).to(equal(["B", "C", "A"]))
            }

            it("Stock の末尾のタスクを先頭へ動かす") {
                let result = useCase.moveStockItem(fromIndex: 2, toOffset: 0, in: [first, second, third])

                expect(result?.map(\.title)).to(equal(["C", "A", "B"]))
            }

            it("位置は Stock 内で数え、配置済みの予定は後ろにまとめる") {
                let result = useCase.moveStockItem(fromIndex: 1, toOffset: 0, in: [first, placed, second])

                expect(result?.map(\.title)).to(equal(["B", "A", "会議"]))
            }

            it("存在しない位置を指定したら何もしない") {
                expect(useCase.moveStockItem(fromIndex: 5, toOffset: 0, in: [first, second])).to(beNil())
            }
        }
    }
}
