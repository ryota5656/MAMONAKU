import Foundation
import Quick
import Nimble
@testable import MAMONAKU

final class ThemeManagerSpec: QuickSpec {
    override class func spec() {
        describe("ThemeManager") {
            it("未保存なら Light で始まり、選んだテーマを保存する") {
                let settings = AppSettingsClient(defaults: makeIsolatedDefaults())
                let manager = ThemeManager(settings: settings)
                expect(manager.theme).to(equal(.light))

                manager.theme = .sakura

                expect(ThemeManager(settings: settings).theme).to(equal(.sakura))
            }

            it("保存値が現在のテーマ名でなければ、旧バージョンの外観設定から移行する") {
                let defaults = makeIsolatedDefaults()
                defaults.set("minimal", forKey: AppGroup.themeKey)
                defaults.set("dark", forKey: AppGroup.legacyAppearanceKey)
                let settings = AppSettingsClient(defaults: defaults)

                let manager = ThemeManager(settings: settings)

                expect(manager.theme).to(equal(.dark))
                expect(settings.themeRawValue).to(equal("dark"))
            }

            it("旧バージョンの配色設定は対応するテーマへ移行する") {
                expect(ThemeManager.migratedPalette(legacyAppearance: "light", legacyPalette: "elegant"))
                    .to(equal(.elegant))
                expect(ThemeManager.migratedPalette(legacyAppearance: "dark", legacyPalette: "pastel"))
                    .to(equal(.pop))
                expect(ThemeManager.migratedPalette(legacyAppearance: nil, legacyPalette: nil))
                    .to(equal(.light))
            }

            it("PLUS 未加入で有料テーマを選んでいる場合だけ System へ戻す") {
                let manager = ThemeManager(settings: AppSettingsClient(defaults: makeIsolatedDefaults()))

                manager.theme = .sakura
                manager.revertToFreeThemeIfNeeded(isSubscribed: true)
                expect(manager.theme).to(equal(.sakura))

                manager.revertToFreeThemeIfNeeded(isSubscribed: false)
                expect(manager.theme).to(equal(.system))

                manager.theme = .dark
                manager.revertToFreeThemeIfNeeded(isSubscribed: false)
                expect(manager.theme).to(equal(.dark))
            }
        }
    }
}
