import SwiftUI

/// ユーザーが選ぶ着せ替えテーマ（外観＋配色を含む、単一選択）。
/// 実際の色は `AppTheme` が持つ。
enum AppPalette: String, CaseIterable, Identifiable {
    case system
    case light
    case dark
    case pop
    case elegant
    case sakura
    case aqua
    case mori

    var id: String { rawValue }

    /// 設定画面へ表示するテーマ一覧（POP / Elegant は一時的に非表示）
    static var visibleInSettings: [AppPalette] {
        allCases.filter { $0 != .pop && $0 != .elegant }
    }

    /// 無料で選択可能なテーマ
    static let freeThemes: [AppPalette] = [.system, .light, .dark]

    var isFreeTheme: Bool {
        Self.freeThemes.contains(self)
    }

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        case .pop: return "POP"
        case .elegant: return "Elegant"
        case .sakura: return "Sakura"
        case .aqua: return "Aqua"
        case .mori: return "Mori"
        }
    }

    /// テーマが要求する外観。`system` は端末設定に従うため nil。
    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light, .pop, .sakura, .aqua, .mori: return .light
        case .dark, .elegant: return .dark
        }
    }
}
