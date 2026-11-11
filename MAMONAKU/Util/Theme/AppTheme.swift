import SwiftUI

/// 画面が参照する配色トークン。
///
/// View は `@Environment(\.appTheme)` でこの値を受け取り、役割名（`textPrimary` など）で色を指定する。
/// テーマを追加・調整するときは `AppTheme+Palettes.swift` の定義だけを変更すればよい。
struct AppTheme: Equatable {
    /// 画面・タイムラインの背景
    let background: Color
    /// カードやリスト行など、背景より一段手前の面
    let surface: Color
    /// タイムラインシートの影
    let shadow: Color

    let textPrimary: Color
    let textSecondary: Color

    /// ボタンや強調に使う差し色
    let accent: Color
    /// `accent` の上に載せる文字・アイコン
    let onAccent: Color
    /// 現在時刻・今日・選択中タブなど、最も強い差し色
    let strongAccent: Color
    /// `strongAccent` の上に載せる文字
    let onStrongAccent: Color

    /// タイムラインの目盛り線・仮配置カードの枠
    let gridLine: Color
    /// 予定カードの色。複数ある場合は予定ごとに振り分ける。
    let itemCardColors: [Color]
}

extension AppTheme {
    /// 選択中テーマと端末の外観から配色を決める。`system` は外観に応じて Light / Dark を使う。
    static func resolve(palette: AppPalette, colorScheme: ColorScheme) -> AppTheme {
        switch palette {
        case .system: return colorScheme == .dark ? .dark : .light
        case .light: return .light
        case .dark: return .dark
        case .pop: return .pop
        case .elegant: return .elegant
        case .sakura: return .sakura
        case .aqua: return .aqua
        case .mori: return .mori
        }
    }

    /// 予定カードの基本色（左レール・編集枠など）。
    var itemCardColor: Color {
        itemCardColors.first ?? .white
    }

    /// 予定 ID から決まる予定カードの色（ドロップ位置のプレビューで使用）。
    func itemCardColor(for id: UUID) -> Color {
        guard !itemCardColors.isEmpty else { return .white }
        return itemCardColors[Int(UInt(bitPattern: id.hashValue) % UInt(itemCardColors.count))]
    }

    /// 優先度を表す色。
    func priorityColor(_ priority: TaskPriority) -> Color {
        switch priority {
        case .low: return textSecondary
        case .medium: return accent
        case .high: return strongAccent
        }
    }
}

// MARK: - Environment

extension EnvironmentValues {
    /// 現在の配色。`appThemeProvider()` を付けた View の配下で、選択中テーマに解決される。
    @Entry var appTheme: AppTheme = .light
}

/// `ThemeManager` の選択と端末の外観から `AppTheme` を解決し、配下の View に渡す。
private struct AppThemeProvider: ViewModifier {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content.environment(
            \.appTheme,
            AppTheme.resolve(palette: themeManager.theme, colorScheme: colorScheme)
        )
    }
}

extension View {
    /// 配下の View が `@Environment(\.appTheme)` で配色を読めるようにする。
    /// 外観（ライト / ダーク）が切り替わる境界（アプリのルート・シートのルート）に付ける。
    func appThemeProvider() -> some View {
        modifier(AppThemeProvider())
    }
}
