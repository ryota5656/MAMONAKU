import CoreGraphics
import Quick
import Nimble
@testable import MAMONAKU

final class TimelineLayoutSpec: QuickSpec {
    override class func spec() {
        describe("TimelineLayout") {
            it("等倍では 1 時間を 80pt として時刻と位置を変換する") {
                let layout = TimelineLayout()

                expect(layout.yOffset(forMinutes: 90)).to(equal(120))
                expect(layout.height(forDurationMinutes: 30)).to(equal(40))
                expect(layout.minutes(atY: 120)).to(equal(90))
                expect(layout.dayHeight).to(equal(1920))
            }

            it("位置から求めた時刻は 0〜24 時に収める") {
                let layout = TimelineLayout()

                expect(layout.minutes(atY: -50)).to(equal(0))
                expect(layout.minutes(atY: 10_000)).to(equal(1440))
            }

            it("移動量は負の値もそのまま分に変換する") {
                let layout = TimelineLayout()

                expect(layout.minutes(forTranslation: -40)).to(equal(-30))
                expect(layout.minutes(forTranslation: 80)).to(equal(60))
            }

            it("拡大すると同じ時刻の位置が比例して伸びる") {
                var layout = TimelineLayout()
                layout.zoom(by: 1.5)

                expect(layout.hourHeight).to(equal(120))
                expect(layout.yOffset(forMinutes: 60)).to(equal(120))
                expect(layout.minutes(atY: 120)).to(equal(60))
            }

            it("拡大率は 0.6〜2.0 倍の範囲から出ない") {
                var layout = TimelineLayout()

                layout.zoom(by: 10)
                expect(layout.zoomScale).to(equal(2.0))

                layout.zoom(by: 0.01)
                expect(layout.zoomScale).to(equal(0.6))
            }
        }
    }
}
