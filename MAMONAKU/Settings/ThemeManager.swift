import SwiftUI
import Combine

/// アプリ全体のテーマ（見た目）を管理するクラス。
/// 今後カスタム配色を増やしたい場合は、このクラスにプロパティを追加していく。
final class ThemeManager: ObservableObject {
    private enum Keys {
        static let theme = AppGroup.themeKey
        // legacy (migrate-once)
        static let appearance = AppGroup.legacyAppearanceKey
        static let palette = AppGroup.legacyPaletteKey
    }

    private static var appGroupDefaults: UserDefaults? { UserDefaults(suiteName: AppGroup.id) }

    @AppStorage(Keys.theme, store: ThemeManager.appGroupDefaults) private var storedTheme: String = AppPalette.system.rawValue
    @AppStorage(Keys.appearance, store: ThemeManager.appGroupDefaults) private var legacyAppearance: String = "system"
    @AppStorage(Keys.palette, store: ThemeManager.appGroupDefaults) private var legacyPalette: String = "minimal"

    /// 現在選択されている着せ替えテーマ
    @Published var theme: AppPalette = .system {
        didSet {
            storedTheme = theme.rawValue
        }
    }

    init() {
        // まず新しいキーを優先
        if let v = AppPalette(rawValue: storedTheme) {
            theme = v
            return
        }

        // 旧データからの移行（appearance/palette を 1つの Theme に畳む）
        let legacyAppearanceValue = legacyAppearance
        let legacyPaletteValue = legacyPalette

        let migrated: AppPalette = {
            // 旧palette (minimal/elegant/pastel) から変換
            if legacyPaletteValue == "elegant" { return .elegant }
            if legacyPaletteValue == "pastel" { return .pop }

            switch legacyAppearanceValue {
            case "light": return .light
            case "dark": return .dark
            default: return .system
            }
        }()

        theme = migrated
        storedTheme = migrated.rawValue
    }
}

