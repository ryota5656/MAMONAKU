import Combine
import SwiftUI

/// 選択中の着せ替えテーマを保持し、App Group の設定へ保存する。
/// 配色そのものは `AppTheme` が持ち、View は `@Environment(\.appTheme)` で受け取る。
final class ThemeManager: ObservableObject {
    private let settings: AppSettingsClient

    /// 現在選択されている着せ替えテーマ
    @Published var theme: AppPalette {
        didSet { settings.themeRawValue = theme.rawValue }
    }

    init(settings: AppSettingsClient) {
        self.settings = settings

        // 未保存なら Light。保存値が読めない場合のみ旧設定（外観 / 配色）から移行する。
        let stored = settings.themeRawValue ?? AppPalette.light.rawValue
        if let palette = AppPalette(rawValue: stored) {
            theme = palette
        } else {
            let migrated = Self.migratedPalette(
                legacyAppearance: settings.legacyAppearanceRawValue,
                legacyPalette: settings.legacyPaletteRawValue
            )
            theme = migrated
            settings.themeRawValue = migrated.rawValue
        }
    }

    /// PLUS 未加入で有料テーマが選ばれている場合、System テーマへ戻す。
    func revertToFreeThemeIfNeeded(isSubscribed: Bool) {
        guard !isSubscribed, !theme.isFreeTheme else { return }
        theme = .system
    }

    /// 旧バージョンの「外観」「配色」の 2 設定を 1 つのテーマに畳む。
    static func migratedPalette(legacyAppearance: String?, legacyPalette: String?) -> AppPalette {
        if legacyPalette == "elegant" { return .elegant }
        if legacyPalette == "pastel" { return .pop }
        return legacyAppearance == "dark" ? .dark : .light
    }
}
