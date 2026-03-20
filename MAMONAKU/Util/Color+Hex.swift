//
//  Color+Hex.swift
//  MAMONAKU
//
//  Created by gpt-5.2-codex on 2026/01/23.
//

import SwiftUI
import UIKit

enum AppGroup {
    static let id = "group.sairyo.MAMONAKU"
    static let themeKey = "settings.theme.selected" // AppPalette を保存
    static let legacyAppearanceKey = "settings.theme.appearance"
    static let legacyPaletteKey = "settings.theme.palette"
}

/// 着せ替えテーマ（外観＋配色を含む、単一選択）。
/// ※ LiveActivityExtension など複数ターゲットから参照されるため、Util 側に定義する。
enum AppPalette: String, CaseIterable, Identifiable {
    case system
    case light
    case dark
    case pop
    case elegant

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "システム"
        case .light: return "ライト"
        case .dark: return "ダーク"
        case .pop: return "POP"
        case .elegant: return "Elegant"
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        case .pop: return .light
        case .elegant: return .dark
        }
    }

    static func loadFromAppGroup() -> AppPalette {
        let defaults = UserDefaults(suiteName: AppGroup.id) ?? .standard
        let raw = defaults.string(forKey: AppGroup.themeKey) ?? AppPalette.system.rawValue
        return AppPalette(rawValue: raw) ?? .system
    }
}

extension Color {
    
    
    /// Initialize a Color from a hex string like "#RRGGBB" or "RRGGBB".
    init(hex: String, alpha: Double = 1.0) {
        let cleaned = hex
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        let value = UInt64(cleaned, radix: 16) ?? 0

        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0

        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

enum AppColors {
    // MARK: - AppPalette で切替（ColorScheme は system 時のみ参照）
    
    static func background(palette: AppPalette, environmentScheme: ColorScheme) -> Color {
        switch (palette, environmentScheme) {
        case (.light, _):
            return Color(hex: "#f3f3f3")
        case (.dark, _):
            return Color(hex: "#1C1C1E")
        case (.pop, _):
            return Color(hex: "#FBFAFF")
        case (.elegant, _):
            return Color(hex: "#141416")
        @unknown default:
            return Color(hex: "#F8F8F8")
        }
    }

    /// サーフェス（カード/シートの内側など）
//    static func surface(palette: AppPalette, environmentScheme: ColorScheme) -> Color {
//        switch (palette, environmentScheme) {
//        case (.light, _):
//            return Color.white
//        case (.dark, _):
//            return Color(hex: "#2C2C2E")
//        case (.pop, _):
//            return Color.white
//        case (.elegant, _):
//            return Color(hex: "#1E1E22")
//        case (.system, .light):
//            return Color.white
//        case (.system, .dark):
//            return Color(hex: "#2C2C2E")
//        @unknown default:
//            return Color.white
//        }
//    }

    static func shadow(palette: AppPalette, environmentScheme: ColorScheme) -> Color {
        switch (palette, environmentScheme) {
        case (.light, _):
            return Color(hex: "#b5bace").opacity(0.5)
        case (.dark, _):
            return Color.black.opacity(0.35)
        case (.pop, _):
            return Color(hex: "#BFC6E6").opacity(0.42)
        case (.elegant, _):
            return Color.black.opacity(0.45)
        case (.system, .light):
            return Color(hex: "#b5bace").opacity(0.5)
        case (.system, .dark):
            return Color.black.opacity(0.35)
        @unknown default:
            return Color(hex: "#b5bace").opacity(0.5)
        }
    }

//    static func divider(palette: AppPalette, environmentScheme: ColorScheme) -> Color {
//        switch (palette, environmentScheme) {
//        case (.light, _):
//            return Color(hex: "#E5E5E5")
//        case (.dark, _):
//            return Color(hex: "#38383A")
//        case (.pop, _):
//            return Color(hex: "#E8E6F4")
//        case (.elegant, _):
//            return Color(hex: "#2F2F33")
//        case (.system, .light):
//            return Color(hex: "#E5E5E5")
//        case (.system, .dark):
//            return Color(hex: "#38383A")
//        @unknown default:
//            return Color(hex: "#E5E5E5")
//        }
//    }

    static func textPrimary(palette: AppPalette, environmentScheme: ColorScheme) -> Color {
        switch (palette, environmentScheme) {
        case (.light, _), (.pop, _), (.system, .light):
            return Color(hex: "#383838")
        case (.dark, _), (.elegant, _), (.system, .dark):
            return Color.primary.opacity(0.9)
        @unknown default:
            return Color(hex: "#111111")
        }
    }
//
//    static func textSecondary(palette: AppPalette, environmentScheme: ColorScheme) -> Color {
//        switch (palette, environmentScheme) {
//        case (.light, _), (.pop, _), (.system, .light):
//            return Color(hex: "#6B6B6B")
//        case (.dark, _), (.elegant, _), (.system, .dark):
//            return Color(hex: "#EBEBF5").opacity(0.6)
//        @unknown default:
//            return Color(hex: "#6B6B6B")
//        }
//    }
    
    /// 強い差し色
    static func strongAccent(palette: AppPalette, environmentScheme: ColorScheme) -> Color {
        switch (palette, environmentScheme) {
        case (.light, _), (.system, .light):
            return Color.red
        case (.dark, _), (.system, .dark):
            return Color.orange
        case (.pop, _):
            return Color(hex: "#7A6FF0")
        case (.elegant, _):
            return Color(hex: "#E6D3A5")
        @unknown default:
            return Color.black
        }
    }

    /// アクセント（ボタンや強調）
    static func accent(palette: AppPalette, environmentScheme: ColorScheme) -> Color {
        switch (palette, environmentScheme) {
        case (.light, _), (.system, .light):
            return Color.black
        case (.dark, _), (.system, .dark):
            return Color.white
        case (.pop, _):
            return Color(hex: "#7A6FF0")
        case (.elegant, _):
            return Color(hex: "#E6D3A5")
        @unknown default:
            return Color.black
        }
    }

    /// `accent` の上に載せるアイコン/テキスト色（視認性優先で白/黒に寄せる）
    static func onAccent(palette: AppPalette, environmentScheme: ColorScheme) -> Color {
        switch (palette, environmentScheme) {
        case (.light, _), (.system, .light):
            return Color.white
        case (.dark, _), (.system, .dark):
            return Color.black
        case (.pop, _):
            return Color.white
        case (.elegant, _):
            return Color.black
        @unknown default:
            return Color.white
        }
    }

    /// 仮配置カードの背景（タイムライン上でドロップ前の入力カード）
    static func pendingCardBackground(palette: AppPalette, environmentScheme: ColorScheme) -> Color {
        switch (palette, environmentScheme) {
        case (.light, _), (.system, .light):
            return Color(hex: "#383838").opacity(0.9)
        case (.dark, _), (.system, .dark):
            return Color(hex: "#48484A").opacity(0.95)
        case (.pop, _):
            return Color(hex: "#2C2A40").opacity(0.92)
        case (.elegant, _):
            return Color(hex: "#2A2A2E").opacity(0.95)
        @unknown default:
            return Color(hex: "#383838").opacity(0.9)
        }
    }
    
    /// 仮配置カードのストローク
    static func pendingCardStroke(palette: AppPalette, environmentScheme: ColorScheme) -> Color {
        switch (palette, environmentScheme) {
        case (.dark, _), (.elegant, _), (.system, .dark):
            return Color.white.opacity(0.35)
        default:
            return Color.white.opacity(0.6)
        }
    }
    
    /// タイムライン項目カードのベース色（複数色を返して分散させる）
    static func itemCardColors(palette: AppPalette, environmentScheme: ColorScheme) -> [Color] {
        switch (palette, environmentScheme) {
        case (.light, _), (.system, .light):
            return [Color(hex: "#383838")]
        case (.dark, _), (.system, .dark):
            return [Color(hex: "#383838")]
        case (.elegant, _):
            return [Color(hex: "#2A2420"), Color(hex: "#242428"), Color(hex: "#1F1F24")]
        case (.pop, _):
            return [Color(hex: "#7A6FF0"), Color(hex: "#F08FB1"), Color(hex: "#5BBAD6")]
        @unknown default:
            return [Color(hex: "#383838")]
        }
    }
    
    // 配置カードのストローク
    static func cardStroke(palette: AppPalette, environmentScheme: ColorScheme) -> Color {
        switch (palette, environmentScheme) {
        case (.light, _), (.system, .light):
            return Color(hex: "#F8F8F8")
        case (.dark, _), (.system, .dark):
            return Color(hex: "#1C1C1E")
        case (.elegant, _):
            return Color.white.opacity(0.35)
        default:
            return Color.white.opacity(0.6)
        }
    }

    /// グリッド線（タイムラインの時間軸の線）
    static func gridLine(palette: AppPalette, environmentScheme: ColorScheme) -> Color {
        switch (palette, environmentScheme) {
        case (.dark, _), (.elegant, _), (.system, .dark):
            return Color.white.opacity(0.12)
        default:
            return Color.black.opacity(0.1)
        }
    }

    /// グリッド面（タイムライン全体の薄い背景）
//    static func gridFill(palette: AppPalette, environmentScheme: ColorScheme) -> Color {
//        switch (palette, environmentScheme) {
//        case (.light, _):
//            return Color(hex: "#F8F8F8")
//        case (.dark, _):
//            return Color(hex: "#1C1C1E")
//        case (.pop, _):
//            return Color(hex: "#FBFAFF")
//        case (.elegant, _):
//            return Color(hex: "#141416")
//        case (.system, .light):
//            return Color(hex: "#F8F8F8")
//        case (.system, .dark):
//            return Color(hex: "#1C1C1E")
//        @unknown default:
//            return Color(hex: "#F8F8F8")
//        }
//    }

    // MARK: - 既存 API（環境の ColorScheme をそのまま使う）

    static func background(for scheme: ColorScheme) -> Color { background(palette: .system, environmentScheme: scheme) }
//    static func surface(for scheme: ColorScheme) -> Color { surface(palette: .system, environmentScheme: scheme) }
    static func shadow(for scheme: ColorScheme) -> Color { shadow(palette: .system, environmentScheme: scheme) }
//    static func divider(for scheme: ColorScheme) -> Color { divider(palette: .system, environmentScheme: scheme) }
    static func textPrimary(for scheme: ColorScheme) -> Color { textPrimary(palette: .system, environmentScheme: scheme) }
//    static func textSecondary(for scheme: ColorScheme) -> Color { textSecondary(palette: .system, environmentScheme: scheme) }
    static func accent(for scheme: ColorScheme) -> Color { accent(palette: .system, environmentScheme: scheme) }
    static func pendingCardBackground(for scheme: ColorScheme) -> Color { pendingCardBackground(palette: .system, environmentScheme: scheme) }
    static func pendingCardStroke(for scheme: ColorScheme) -> Color { pendingCardStroke(palette: .system, environmentScheme: scheme) }
    static func gridLine(for scheme: ColorScheme) -> Color { gridLine(palette: .system, environmentScheme: scheme) }
//    static func gridFill(for scheme: ColorScheme) -> Color { gridFill(palette: .system, environmentScheme: scheme) }
    static func itemCardColors(for scheme: ColorScheme) -> [Color] { itemCardColors(palette: .system, environmentScheme: scheme) }

    // MARK: - 後方互換（デフォルトはライト）

    static var background: Color { background(for: .light) }
    static var systemBackground: Color { Color(uiColor: .systemBackground) }
    static var systemBackgroundSecondary: Color { Color(uiColor: .secondarySystemBackground) }
    static var shadow: Color { shadow(for: .light) }
    static var textPrimary: Color { textPrimary(for: .light) }
//    static var textSecondary: Color { textSecondary(for: .light) }
//    static var divider: Color { divider(for: .light) }
    static var accent: Color { accent(for: .light) }
}
