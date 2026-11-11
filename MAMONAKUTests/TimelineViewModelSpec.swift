import Foundation
import Quick
import Nimble
@testable import MAMONAKU

final class TimelineViewModelSpec: AsyncSpec {
    override class func spec() {
        let tutorialCompletedKey = "tutorial.firstRun.completed"
        let today = TestTime.today

        /// 9:00 時点のタイムライン画面を、偽のリポジトリで組み立てる。
        @MainActor
        struct Harness {
            let repository: FakeTimelineRepository
            let notifications = FakeTimelineNotificationRepository()
            let liveActivity = FakeLiveActivityRepository()
            let defaults = makeIsolatedDefaults()
            let clock = TestClock(now: TestTime.date(hour: 9))
            let viewModel: TimelineViewModel

            init(items: [TimelineItem] = [], isTutorialCompleted: Bool = true) {
                repository = FakeTimelineRepository(items: items)
                defaults.set(isTutorialCompleted, forKey: "tutorial.firstRun.completed")
                viewModel = TimelineViewModel(
                    repository: repository,
                    notificationRepository: notifications,
                    liveActivityRepository: liveActivity,
                    localDefaults: defaults,
                    calendar: TestTime.calendar,
                    now: { [clock] in clock.now },
                    repositoryPollingInterval: nil,
                    minimumRefreshIndicatorDuration: 0
                )
            }

            /// 等倍表示で、指定した時刻（0 時からの分）にあたるタイムライン上の位置
            func y(atMinutes minutes: Int) -> CGFloat {
                TimelineLayout().yOffset(forMinutes: minutes)
            }
        }

        describe("起動時") {
            it("保存済みの予定を読み込み、今日を表示して通知を登録し直す") { @MainActor in
                let items: [TimelineItem] = [.placed("会議", startMinutes: 600), .stock("資料作成")]

                let harness = Harness(items: items)

                expect(harness.viewModel.state.items).to(equal(items))
                expect(harness.viewModel.state.selectedDate).to(equal(today))
                expect(harness.notifications.startRescheduleCount).to(equal(1))
                expect(harness.notifications.bufferRescheduleCount).to(equal(1))
            }
        }

        describe("初回チュートリアル") {
            it("初回は Stock に練習用タスクを用意して、配置を促す") { @MainActor in
                let harness = Harness(isTutorialCompleted: false)

                harness.viewModel.onAppear()

                expect(harness.viewModel.state.tutorialStep).to(equal(.placeTaskAfterNow))
                expect(harness.viewModel.state.stockItems.map(\.title)).to(equal(["はじめてのタスク"]))
                expect(harness.repository.items.map(\.title)).to(equal(["はじめてのタスク"]))
            }

            it("Stock にタスクがあれば練習用タスクは追加しない") { @MainActor in
                let harness = Harness(items: [.stock("資料作成")], isTutorialCompleted: false)

                harness.viewModel.onAppear()

                expect(harness.viewModel.state.tutorialStep).to(equal(.placeTaskAfterNow))
                expect(harness.viewModel.state.items.map(\.title)).to(equal(["資料作成"]))
            }

            it("完了済みならチュートリアルを出さない") { @MainActor in
                let harness = Harness(isTutorialCompleted: true)

                harness.viewModel.onAppear()

                expect(harness.viewModel.state.tutorialStep).to(beNil())
                expect(harness.viewModel.state.items).to(beEmpty())
            }

            it("タスクを現在時刻より後に置くと、完了ボタンの案内へ進む") { @MainActor in
                let harness = Harness(isTutorialCompleted: false)
                harness.viewModel.onAppear()
                let taskID = harness.viewModel.state.stockItems[0].id

                harness.viewModel.timelineDidDropItem(id: taskID, on: today, y: harness.y(atMinutes: 600))

                expect(harness.viewModel.state.tutorialStep).to(equal(.confirmComplete))
            }

            it("現在時刻より前に置いただけでは次へ進まない") { @MainActor in
                let harness = Harness(isTutorialCompleted: false)
                harness.viewModel.onAppear()
                let taskID = harness.viewModel.state.stockItems[0].id

                harness.viewModel.timelineDidDropItem(id: taskID, on: today, y: harness.y(atMinutes: 480))

                expect(harness.viewModel.state.tutorialStep).to(equal(.placeTaskAfterNow))
            }

            it("最後に完了ボタンを押すと Live Activity へ反映し、通知の許可を求めて終了する") { @MainActor in
                let harness = Harness(isTutorialCompleted: false)
                harness.viewModel.onAppear()
                let taskID = harness.viewModel.state.stockItems[0].id
                harness.viewModel.timelineDidDropItem(id: taskID, on: today, y: harness.y(atMinutes: 600))

                await harness.viewModel.trailingActionDidTap()

                expect(harness.viewModel.state.tutorialStep).to(beNil())
                expect(harness.viewModel.state.isEditing).to(beFalse())
                expect(harness.liveActivity.commitSyncCount).to(equal(1))
                expect(harness.notifications.authorizationRequestCount).to(equal(1))
                expect(harness.defaults.bool(forKey: tutorialCompletedKey)).to(beTrue())
            }

            it("「あとで」を選ぶと、通知の許可は求めずに終了する") { @MainActor in
                let harness = Harness(isTutorialCompleted: false)
                harness.viewModel.onAppear()

                harness.viewModel.timelineDidTapSkipTutorial()

                let didFinish = await eventually { harness.viewModel.state.tutorialStep == nil }
                expect(didFinish).to(beTrue())
                expect(harness.defaults.bool(forKey: tutorialCompletedKey)).to(beTrue())
                expect(harness.notifications.authorizationRequestCount).to(equal(0))
            }
        }

        describe("Stock からタイムラインへの配置") {
            it("配置を保存して通知を登録し直し、Live Activity を未反映にして編集モードへ入る") { @MainActor in
                let task = TimelineItem.stock("資料作成")
                let harness = Harness(items: [task])

                harness.viewModel.timelineDidDropItem(id: task.id, on: today, y: harness.y(atMinutes: 600))

                expect(harness.repository.items.first?.startMinutes).to(equal(600))
                expect(harness.repository.items.first?.dropDate).to(equal(today))
                expect(harness.notifications.startRescheduleCount).to(equal(2))
                expect(harness.viewModel.state.isLiveActivitySyncPending).to(beTrue())
                expect(harness.viewModel.state.isEditing).to(beTrue())
            }

            it("他の予定と重なる位置へのドロップは無視する") { @MainActor in
                let task = TimelineItem.stock("資料作成")
                let existing = TimelineItem.placed("会議", startMinutes: 600, durationMinutes: 60)
                let harness = Harness(items: [task, existing])

                harness.viewModel.timelineDidDropItem(id: task.id, on: today, y: harness.y(atMinutes: 630))

                expect(harness.viewModel.state.stockItems.map(\.title)).to(equal(["資料作成"]))
                expect(harness.repository.saveCount).to(equal(0))
            }

            it("ドラッグ中はドロップ位置のプレビューを出し、領域の外へ出たら消す") { @MainActor in
                let task = TimelineItem.stock("資料作成")
                let harness = Harness(items: [task])

                harness.viewModel.timelineDidHoverDrop(itemID: task.id, on: today, y: harness.y(atMinutes: 602))
                expect(harness.viewModel.state.dropPreview?.startMinutes).to(equal(600))

                harness.viewModel.timelineDidExitDropArea()
                expect(harness.viewModel.state.dropPreview).to(beNil())
            }

            it("配置済みの予定を Stock へドロップすると未配置に戻す") { @MainActor in
                let item = TimelineItem.placed("会議", startMinutes: 600)
                let harness = Harness(items: [item])

                harness.viewModel.timelineDidDropItemOnStock(id: item.id)

                expect(harness.viewModel.state.stockItems.map(\.title)).to(equal(["会議"]))
                expect(harness.repository.items.first?.isInStock).to(beTrue())
            }
        }

        describe("長押しによる作成") {
            it("長押し → 指を動かす → 離す → タイトル入力 で予定を作る") { @MainActor in
                let harness = Harness()
                let viewModel = harness.viewModel

                viewModel.timelineDidBeginLongPress(on: today, y: harness.y(atMinutes: 600))
                expect(viewModel.state.pendingPlacement?.durationMinutes).to(equal(30))

                viewModel.timelineDidMoveLongPress(on: today, y: harness.y(atMinutes: 660))
                expect(viewModel.state.pendingPlacement?.durationMinutes).to(equal(60))

                viewModel.timelineDidEndLongPress()
                expect(viewModel.state.pendingPlacement?.isAwaitingTitle).to(beTrue())

                viewModel.timelineDidSubmitPendingPlacementTitle("打ち合わせ")

                expect(viewModel.state.pendingPlacement).to(beNil())
                expect(harness.repository.items.map(\.title)).to(equal(["打ち合わせ"]))
                expect(harness.repository.items.first?.startMinutes).to(equal(600))
                expect(harness.repository.items.first?.durationMinutes).to(equal(60))
                expect(viewModel.state.isEditing).to(beTrue())
            }

            it("タイトル入力待ちのときに空き領域をタップすると作成をやめる") { @MainActor in
                let harness = Harness()
                harness.viewModel.timelineDidBeginLongPress(on: today, y: harness.y(atMinutes: 600))
                harness.viewModel.timelineDidEndLongPress()

                harness.viewModel.timelineDidTapEmptyArea()

                expect(harness.viewModel.state.pendingPlacement).to(beNil())
                expect(harness.repository.items).to(beEmpty())
            }
        }

        describe("シートからの作成・編集・削除") {
            it("＋ をタップすると作成シートを開き、作成すると Stock に追加して閉じる") { @MainActor in
                let harness = Harness()

                harness.viewModel.timelineDidTapAddTask()
                expect(harness.viewModel.state.sheet).to(equal(.createTask))

                harness.viewModel.createTask(
                    title: "資料作成", durationMinutes: 45, priority: .low, startDate: nil, endDate: nil
                )

                expect(harness.viewModel.state.sheet).to(beNil())
                expect(harness.viewModel.state.stockItems.map(\.title)).to(equal(["資料作成"]))
                expect(harness.repository.items.map(\.title)).to(equal(["資料作成"]))
            }

            it("Stock のタスクをタップすると編集シートを開き、保存すると内容を更新する") { @MainActor in
                let task = TimelineItem.stock("資料作成")
                let harness = Harness(items: [task])

                harness.viewModel.timelineDidTapStockItem(id: task.id)
                expect(harness.viewModel.state.sheet).to(equal(.editTask(task)))

                harness.viewModel.updateTask(id: task.id, title: "資料レビュー", durationMinutes: 60, priority: .high)

                expect(harness.viewModel.state.sheet).to(beNil())
                expect(harness.repository.items.first?.title).to(equal("資料レビュー"))
                expect(harness.repository.items.first?.durationMinutes).to(equal(60))
                expect(harness.repository.items.first?.priority).to(equal(.high))
            }

            it("繰り返すと終了日までの予定を作り、一覧からまとめて消せる") { @MainActor in
                let harness = Harness()
                let weekday = TestTime.calendar.component(.weekday, from: today)
                harness.viewModel.timelineDidTapRoutines()
                expect(harness.viewModel.state.sheet).to(equal(.routines))
                harness.viewModel.dismissSheet()

                let didCreate = harness.viewModel.createTask(
                    title: "バイト",
                    durationMinutes: 120,
                    priority: .medium,
                    startDate: TestTime.date(hour: 18),
                    endDate: TestTime.date(hour: 22),
                    repeatRule: RoutineRepeat(weekdays: [weekday], endDate: today)
                )

                expect(didCreate).to(beTrue())
                expect(harness.viewModel.state.sheet).to(beNil())
                let didSync = await eventually { harness.liveActivity.syncAllSchedulesCount == 1 }
                expect(didSync).to(beTrue())
                expect(harness.repository.routines.map(\.title)).to(equal(["バイト"]))
                expect(harness.repository.items.map(\.routineID)).to(equal([harness.repository.routines.first?.id]))

                let routineID = harness.repository.routines[0].id
                harness.viewModel.deleteRoutine(id: routineID)

                expect(harness.repository.deletedRoutineIDs).to(equal([routineID]))
                expect(harness.repository.items).to(beEmpty())
                expect(harness.repository.routines).to(beEmpty())
                expect(harness.viewModel.state.isLiveActivitySyncPending).to(beTrue())
            }

            it("一覧から編集すると、紐づいている予定へ反映し、一覧は開いたままにする") { @MainActor in
                let harness = Harness()
                let weekday = TestTime.calendar.component(.weekday, from: today)
                harness.viewModel.createTask(
                    title: "バイト",
                    durationMinutes: 120,
                    priority: .low,
                    startDate: TestTime.date(hour: 18),
                    endDate: TestTime.date(hour: 22),
                    repeatRule: RoutineRepeat(weekdays: [weekday], endDate: today)
                )
                harness.viewModel.timelineDidTapRoutines()
                let routineID = harness.repository.routines[0].id

                let didSave = harness.viewModel.updateRoutine(
                    id: routineID,
                    title: "夜バイト",
                    priority: .high,
                    startDate: TestTime.date(hour: 19),
                    endDate: TestTime.date(hour: 22),
                    repeatRule: RoutineRepeat(weekdays: [weekday], endDate: today)
                )

                expect(didSave).to(beTrue())
                let didSync = await eventually { harness.liveActivity.syncAllSchedulesCount == 2 }
                expect(didSync).to(beTrue())
                expect(harness.viewModel.state.sheet).to(equal(.routines))
                expect(harness.repository.routines.first?.title).to(equal("夜バイト"))
                expect(harness.repository.items.first?.title).to(equal("夜バイト"))
                expect(harness.repository.items.first?.startMinutes).to(equal(19 * 60))
                expect(harness.repository.items.first?.routineID).to(equal(routineID))
            }

            it("1日だけ時刻をずらすと、その日は一括削除に含まれない") { @MainActor in
                let harness = Harness()
                let weekday = TestTime.calendar.component(.weekday, from: today)
                harness.viewModel.createTask(
                    title: "バイト",
                    durationMinutes: 120,
                    priority: .low,
                    startDate: TestTime.date(hour: 18),
                    endDate: TestTime.date(hour: 22),
                    repeatRule: RoutineRepeat(
                        weekdays: [weekday],
                        endDate: TestTime.calendar.date(byAdding: .day, value: 7, to: today)!
                    )
                )
                let movedID = harness.repository.items[0].id
                harness.viewModel.timelineDidDropItem(id: movedID, on: today, y: harness.y(atMinutes: 19 * 60))

                let routineID = harness.repository.items.compactMap(\.routineID).first
                expect(harness.repository.items.first { $0.id == movedID }?.routineID).to(beNil())
                harness.viewModel.deleteRoutine(id: routineID!)

                expect(harness.repository.items.map(\.id)).to(equal([movedID]))
            }

            it("削除すると保存先からも消し、Live Activity を未反映にする") { @MainActor in
                let task = TimelineItem.stock("資料作成")
                let harness = Harness(items: [task])

                harness.viewModel.deleteTask(id: task.id)

                expect(harness.repository.deletedIDs).to(equal([task.id]))
                expect(harness.viewModel.state.items).to(beEmpty())
                expect(harness.viewModel.state.isLiveActivitySyncPending).to(beTrue())
            }
        }

        describe("タブバー右端のボタン（完了 / 更新）") {
            it("編集中は編集モードを抜け、未反映の変更を Live Activity へ反映する") { @MainActor in
                let task = TimelineItem.stock("資料作成")
                let harness = Harness(items: [task])
                harness.viewModel.timelineDidDropItem(id: task.id, on: today, y: harness.y(atMinutes: 600))

                await harness.viewModel.trailingActionDidTap()

                expect(harness.viewModel.state.isEditing).to(beFalse())
                expect(harness.liveActivity.commitSyncCount).to(equal(1))
                expect(harness.viewModel.state.isLiveActivitySyncPending).to(beFalse())
                expect(harness.viewModel.state.isLiveActivityRefreshing).to(beFalse())
            }

            it("未反映の変更が無ければ Live Activity へは送らない") { @MainActor in
                let harness = Harness(items: [.placed("会議", startMinutes: 600)])

                await harness.viewModel.trailingActionDidTap()

                expect(harness.liveActivity.commitSyncCount).to(equal(0))
            }
        }

        describe("編集モード") {
            it("予定を長押しすると編集モードへ入る") { @MainActor in
                let item = TimelineItem.placed("会議", startMinutes: 600)
                let harness = Harness(items: [item])

                harness.viewModel.timelineDidLongPressItem(id: item.id)

                expect(harness.viewModel.state.isEditing).to(beTrue())
            }

            it("編集モードを抜けた直後（0.6 秒以内）の長押しでは入り直さない") { @MainActor in
                let item = TimelineItem.placed("会議", startMinutes: 600)
                let harness = Harness(items: [item])
                harness.viewModel.timelineDidLongPressItem(id: item.id)
                await harness.viewModel.trailingActionDidTap()

                harness.clock.advance(by: 0.3)
                harness.viewModel.timelineDidLongPressItem(id: item.id)

                expect(harness.viewModel.state.isEditing).to(beFalse())
            }

            it("編集モードを抜けて 0.6 秒以上たてば、長押しで入り直せる") { @MainActor in
                let item = TimelineItem.placed("会議", startMinutes: 600)
                let harness = Harness(items: [item])
                harness.viewModel.timelineDidLongPressItem(id: item.id)
                await harness.viewModel.trailingActionDidTap()

                harness.clock.advance(by: 0.7)
                harness.viewModel.timelineDidLongPressItem(id: item.id)

                expect(harness.viewModel.state.isEditing).to(beTrue())
            }

            it("リサイズ中はプレビューを出し、指を離すと所要時間を確定する") { @MainActor in
                let item = TimelineItem.placed("会議", startMinutes: 600, durationMinutes: 30)
                let harness = Harness(items: [item])

                harness.viewModel.timelineDidDragResizeHandle(itemID: item.id, translation: 40)
                expect(harness.viewModel.state.resizePreview?.durationMinutes).to(equal(60))

                harness.viewModel.timelineDidReleaseResizeHandle(itemID: item.id, translation: 40)

                expect(harness.viewModel.state.resizePreview).to(beNil())
                expect(harness.repository.items.first?.durationMinutes).to(equal(60))
            }
        }

        describe("日付の切り替え") {
            it("別の日を選ぶとその日を表示する") { @MainActor in
                let harness = Harness()

                harness.viewModel.timelineDidSelectDate(TestTime.tomorrow.addingTimeInterval(3600))

                expect(harness.viewModel.state.selectedDate).to(equal(TestTime.tomorrow))
            }

            it("タイムラインタブをもう一度タップすると今日へ戻り、現在時刻へスクロールする") { @MainActor in
                let harness = Harness()
                harness.viewModel.timelineDidSelectDate(TestTime.tomorrow)

                harness.viewModel.timelineTabDidReselect()

                expect(harness.viewModel.state.selectedDate).to(equal(today))
                expect(harness.viewModel.state.scrollToNowRequestID).toNot(beNil())
            }

            it("日付ラベルをタップすると日付選択シートを開く") { @MainActor in
                let harness = Harness()

                harness.viewModel.timelineDidTapDateLabel()

                expect(harness.viewModel.state.sheet).to(equal(.datePicker))
            }
        }

        describe("前面復帰") {
            it("表示中の Live Activity が古くなっていないか確認する") { @MainActor in
                let harness = Harness()

                await harness.viewModel.sceneDidBecomeActive()

                expect(harness.liveActivity.refreshIfOverdueCount).to(equal(1))
            }
        }
    }
}
