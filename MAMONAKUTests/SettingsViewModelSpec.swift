import Foundation
import Quick
import Nimble
@testable import MAMONAKU

final class SettingsViewModelSpec: AsyncSpec {
    override class func spec() {
        @MainActor
        struct Harness {
            let settings = AppSettingsClient(defaults: makeIsolatedDefaults())
            let repository = FakeTimelineRepository()
            let notifications = FakeTimelineNotificationRepository()
            let viewModel: SettingsViewModel

            init(isSubscribed: Bool, bufferMinutes: Int = 10) {
                settings.globalBufferMinutes = bufferMinutes
                viewModel = SettingsViewModel(
                    settings: settings,
                    timelineRepository: repository,
                    notificationRepository: notifications
                )
                viewModel.environmentDidChange(
                    isSubscribed: isSubscribed,
                    selectedTheme: .light,
                    isDebugSubscriptionOverridden: false
                )
            }
        }

        describe("バッファ通知のタイミング") {
            it("＋ で 5 分ずつ増やし、保存してバッファ通知を登録し直す") { @MainActor in
                let harness = Harness(isSubscribed: true, bufferMinutes: 10)

                harness.viewModel.settingsDidIncrementBufferMinutes()

                expect(harness.viewModel.state.bufferMinutes).to(equal(15))
                expect(harness.settings.globalBufferMinutes).to(equal(15))
                expect(harness.notifications.bufferRescheduleCount).to(equal(1))
            }

            it("1 分からの ＋ は 5 分にする") { @MainActor in
                let harness = Harness(isSubscribed: true, bufferMinutes: 1)

                harness.viewModel.settingsDidIncrementBufferMinutes()

                expect(harness.viewModel.state.bufferMinutes).to(equal(5))
            }

            it("5 分からの − は最短の 1 分にする") { @MainActor in
                let harness = Harness(isSubscribed: true, bufferMinutes: 5)

                harness.viewModel.settingsDidDecrementBufferMinutes()

                expect(harness.viewModel.state.bufferMinutes).to(equal(1))
            }

            it("上限の 120 分を超えない") { @MainActor in
                let harness = Harness(isSubscribed: true, bufferMinutes: 120)

                harness.viewModel.settingsDidIncrementBufferMinutes()

                expect(harness.viewModel.state.bufferMinutes).to(equal(120))
            }

            it("PLUS 未加入では変更しない") { @MainActor in
                let harness = Harness(isSubscribed: false, bufferMinutes: 10)

                harness.viewModel.settingsDidIncrementBufferMinutes()

                expect(harness.viewModel.state.bufferMinutes).to(equal(10))
                expect(harness.settings.globalBufferMinutes).to(equal(10))
                expect(harness.notifications.bufferRescheduleCount).to(equal(0))
            }
        }

        describe("通知・Live Activity の設定") {
            it("開始通知を切り替えると保存し、開始通知を登録し直す") { @MainActor in
                let harness = Harness(isSubscribed: false)

                harness.viewModel.settingsDidToggleStartNotification(false)

                expect(harness.viewModel.state.isStartNotificationEnabled).to(beFalse())
                expect(harness.settings.isStartNotificationEnabled).to(beFalse())
                expect(harness.notifications.startRescheduleCount).to(equal(1))
            }

            it("PLUS 限定の設定は未加入では変更しない") { @MainActor in
                let harness = Harness(isSubscribed: false)

                harness.viewModel.settingsDidToggleBufferNotification(true)
                harness.viewModel.settingsDidToggleLiveActivityStack(false)

                expect(harness.settings.isBufferNotificationPreferred).to(beFalse())
                expect(harness.settings.isLiveActivityStackPreferred).to(beTrue())
            }

            it("通知の許可をオンにすると許可を求め、結果を表示に反映する") { @MainActor in
                let harness = Harness(isSubscribed: false)

                harness.viewModel.settingsDidToggleNotificationPermission(true)

                let isGranted = await eventually { harness.viewModel.state.isNotificationPermissionGranted }
                expect(isGranted).to(beTrue())
                expect(harness.notifications.authorizationRequestCount).to(equal(1))
            }

            it("通知の許可をオフにしようとしたら iOS の設定アプリへ案内する") { @MainActor in
                let harness = Harness(isSubscribed: false)

                harness.viewModel.settingsDidToggleNotificationPermission(false)

                expect(harness.viewModel.route).to(equal(.openSystemSettings))
            }

            it("画面表示時に、端末の通知許可の状態を読み直す") { @MainActor in
                let harness = Harness(isSubscribed: false)
                harness.notifications.isAuthorizedValue = true

                await harness.viewModel.onAppear()

                expect(harness.viewModel.state.isNotificationPermissionGranted).to(beTrue())
            }
        }

        describe("標準カレンダー同期") {
            it("カレンダーへのアクセスが許可されたら同期をオンにする") { @MainActor in
                let harness = Harness(isSubscribed: true)

                harness.viewModel.settingsDidToggleCalendarSync(true)

                let isEnabled = await eventually { harness.viewModel.state.isCalendarSyncEnabled }
                expect(isEnabled).to(beTrue())
                expect(harness.repository.calendarSyncEnabledHistory).to(equal([true]))
            }

            it("アクセスが許可されなければオフのままにする") { @MainActor in
                let harness = Harness(isSubscribed: true)
                harness.repository.isCalendarAccessGranted = false

                harness.viewModel.settingsDidToggleCalendarSync(true)

                let didRespond = await eventually { harness.repository.calendarSyncEnabledHistory == [false] }
                expect(didRespond).to(beTrue())
                expect(harness.viewModel.state.isCalendarSyncEnabled).to(beFalse())
            }

            it("PLUS 未加入では切り替えない") { @MainActor in
                let harness = Harness(isSubscribed: false)

                harness.viewModel.settingsDidToggleCalendarSync(false)

                expect(harness.repository.calendarSyncEnabledHistory).to(beEmpty())
            }
        }

        describe("テーマ・PLUS の案内") {
            it("無料テーマは未加入でも適用を指示する") { @MainActor in
                let harness = Harness(isSubscribed: false)

                harness.viewModel.settingsDidSelectTheme(.dark)

                expect(harness.viewModel.route).to(equal(.applyTheme(.dark)))
                expect(harness.viewModel.state.isSubscriptionSheetPresented).to(beFalse())
            }

            it("有料テーマを未加入で選ぶと、適用せず PLUS の案内を出す") { @MainActor in
                let harness = Harness(isSubscribed: false)

                harness.viewModel.settingsDidSelectTheme(.sakura)

                expect(harness.viewModel.route).to(beNil())
                expect(harness.viewModel.state.isSubscriptionSheetPresented).to(beTrue())
            }

            it("PLUS 限定の行をタップすると PLUS の案内を出し、閉じると消える") { @MainActor in
                let harness = Harness(isSubscribed: false)

                harness.viewModel.settingsDidTapLockedFeature()
                expect(harness.viewModel.state.isSubscriptionSheetPresented).to(beTrue())

                harness.viewModel.dismissSubscriptionSheet()
                expect(harness.viewModel.state.isSubscriptionSheetPresented).to(beFalse())
            }
        }
    }
}
