import Foundation
import Quick
import Nimble
@testable import MAMONAKU

final class AppSettingsClientSpec: QuickSpec {
    override class func spec() {
        describe("AppSettingsClient") {
            it("何も保存されていないときは既定値を返す") {
                let settings = AppSettingsClient(defaults: makeIsolatedDefaults())

                expect(settings.isSubscribed).to(beFalse())
                expect(settings.isCalendarSyncPreferred).to(beFalse())
                expect(settings.isStartNotificationEnabled).to(beTrue())
                expect(settings.isBufferNotificationPreferred).to(beFalse())
                expect(settings.globalBufferMinutes).to(equal(10))
                expect(settings.isLiveActivityEnabled).to(beTrue())
                expect(settings.isLiveActivityStackPreferred).to(beTrue())
                expect(settings.isLiveActivitySyncPending).to(beFalse())
            }

            it("バッファ分は 1〜120 分に収めて保存する") {
                let settings = AppSettingsClient(defaults: makeIsolatedDefaults())

                settings.globalBufferMinutes = 500
                expect(settings.globalBufferMinutes).to(equal(120))

                settings.globalBufferMinutes = 0
                expect(settings.globalBufferMinutes).to(equal(1))
            }

            it("カレンダー同期とバッファ通知は、オンにしていても PLUS 未加入なら無効") {
                let settings = AppSettingsClient(defaults: makeIsolatedDefaults())
                settings.isCalendarSyncPreferred = true
                settings.isBufferNotificationPreferred = true

                expect(settings.isCalendarSyncEnabled).to(beFalse())
                expect(settings.isBufferNotificationEnabled).to(beFalse())

                settings.isSubscribed = true

                expect(settings.isCalendarSyncEnabled).to(beTrue())
                expect(settings.isBufferNotificationEnabled).to(beTrue())
            }

            it("Live Activity のスタック表示は PLUS 加入かつ設定オンのときだけ") {
                let settings = AppSettingsClient(defaults: makeIsolatedDefaults())
                expect(settings.liveActivityPlanScope).to(equal(.free))

                settings.isSubscribed = true
                expect(settings.liveActivityPlanScope).to(equal(.plus))

                settings.isLiveActivityStackPreferred = false
                expect(settings.liveActivityPlanScope).to(equal(.free))
            }

            it("予定に適用するバッファ分は、バッファ通知が無効なら nil") {
                let settings = AppSettingsClient(defaults: makeIsolatedDefaults())
                settings.isSubscribed = true
                settings.globalBufferMinutes = 15

                expect(settings.effectiveBufferMinutes(itemOverride: nil)).to(beNil())

                settings.isBufferNotificationPreferred = true

                expect(settings.effectiveBufferMinutes(itemOverride: nil)).to(equal(15))
                expect(settings.effectiveBufferMinutes(itemOverride: 3)).to(equal(3))
                expect(settings.effectiveBufferMinutes(itemOverride: 999)).to(equal(120))
            }
        }
    }
}
