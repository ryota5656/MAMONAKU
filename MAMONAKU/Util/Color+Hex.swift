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
    static let globalBufferMinutesKey = "settings.notification.global_buffer_minutes"
    static let bufferNotificationEnabledKey = "settings.notification.buffer_enabled"
    static let startNotificationEnabledKey = "settings.notification.start_enabled"
    static let liveActivityEnabledKey = "settings.live_activity.enabled"
    static let liveActivityMultipleEnabledKey = "settings.live_activity.multiple_enabled"
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
    case sakura
    case aqua
    case mori

    var id: String { rawValue }

    /// 一時的に設定画面へ表示するテーマ一覧（POP / Elegant は非表示）
    static var visibleInSettings: [AppPalette] {
        allCases.filter { $0 != .pop && $0 != .elegant }
    }

    /// 無料で選択可能なテーマ
    static var freeThemes: [AppPalette] {
        [.system, .light, .dark]
    }

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

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        case .pop: return .light
        case .elegant: return .dark
        case .sakura: return .light
        case .aqua: return .light
        case .mori: return .light
        }
    }

    static func loadFromAppGroup() -> AppPalette {
        let defaults = UserDefaults(suiteName: AppGroup.id) ?? .standard
        let raw = defaults.string(forKey: AppGroup.themeKey) ?? AppPalette.system.rawValue
        return AppPalette(rawValue: raw) ?? .system
    }
}

enum AppColors {
    // MARK: - AppPalette で切替（ColorScheme は system 時のみ参照）
    private static func literal(_ color: UIColor) -> Color {
        Color(uiColor: color)
    }

    private static func resolvedPalette(_ palette: AppPalette, environmentScheme: ColorScheme) -> AppPalette {
        guard palette == .system else { return palette }
        return environmentScheme == .dark ? .dark : .light
    }
    
    static func background(palette: AppPalette, environmentScheme: ColorScheme) -> Color {
        switch resolvedPalette(palette, environmentScheme: environmentScheme) {
        case .light:
            return literal(#colorLiteral(red: 0.9529411765, green: 0.9529411765, blue: 0.9529411765, alpha: 1))
        case .dark:
            return literal(#colorLiteral(red: 0.1098039216, green: 0.1098039216, blue: 0.1176470588, alpha: 1))
        case .pop:
            return literal(#colorLiteral(red: 0.9843137255, green: 0.9803921569, blue: 1, alpha: 1))
        case .elegant:
            return literal(#colorLiteral(red: 0.0784313725, green: 0.0784313725, blue: 0.0862745098, alpha: 1))
        case .sakura:
            return literal(#colorLiteral(red: 0.9921568627, green: 0.9137254902, blue: 0.9450980392, alpha: 1))
        case .aqua:
            return literal(#colorLiteral(red: 0.9490196078, green: 0.968627451, blue: 1, alpha: 1))
        case .mori:
            return literal(#colorLiteral(red: 0.9176470588, green: 0.9411764706, blue: 0.9019607843, alpha: 1))
        case .system:
            return literal(#colorLiteral(red: 0.9725490196, green: 0.9725490196, blue: 0.9725490196, alpha: 1))
        }
    }

    static func shadow(palette: AppPalette, environmentScheme: ColorScheme) -> Color {
        switch resolvedPalette(palette, environmentScheme: environmentScheme) {
        case .light:
            return literal(#colorLiteral(red: 0.7098039216, green: 0.7294117647, blue: 0.8078431373, alpha: 1)).opacity(0.5)
        case .dark:
            return Color.black.opacity(0.35)
        case .pop:
            return literal(#colorLiteral(red: 0.7490196078, green: 0.7764705882, blue: 0.9019607843, alpha: 1)).opacity(0.42)
        case .elegant:
            return Color.black.opacity(0.45)
        case .sakura:
            return literal(#colorLiteral(red: 0.831372549, green: 0.6039215686, blue: 0.7058823529, alpha: 1)).opacity(0.45)
        case .aqua:
            return literal(#colorLiteral(red: 0.7176470588, green: 0.7882352941, blue: 0.9098039216, alpha: 1)).opacity(0.45)
        case .mori:
            return literal(#colorLiteral(red: 0.6196078431, green: 0.6980392157, blue: 0.6156862745, alpha: 1)).opacity(0.45)
        case .system:
            return literal(#colorLiteral(red: 0.7098039216, green: 0.7294117647, blue: 0.8078431373, alpha: 1)).opacity(0.5)
        }
    }

    // MARK: text color
    static func textPrimary(palette: AppPalette, environmentScheme: ColorScheme) -> Color {
        switch resolvedPalette(palette, environmentScheme: environmentScheme) {
        case .light, .pop:
            return literal(#colorLiteral(red: 0.2196078431, green: 0.2196078431, blue: 0.2196078431, alpha: 1))
        case .dark, .elegant:
            return Color.primary.opacity(0.9)
        case .sakura:
            return literal(#colorLiteral(red: 0.5098039216, green: 0.3529411765, blue: 0.4117647059, alpha: 1))
        case .aqua:
            return literal(#colorLiteral(red: 0.1843137255, green: 0.2352941176, blue: 0.3333333333, alpha: 1))
        case .mori:
            return literal(#colorLiteral(red: 0.1803921569, green: 0.2274509804, blue: 0.1843137255, alpha: 1))
        case .system:
            return literal(#colorLiteral(red: 0.0666666667, green: 0.0666666667, blue: 0.0666666667, alpha: 1))
        }
    }

    static func textSecondary(palette: AppPalette, environmentScheme: ColorScheme) -> Color {
        switch resolvedPalette(palette, environmentScheme: environmentScheme) {
        case .light:
            return literal(#colorLiteral(red: 0.4196078431, green: 0.4196078431, blue: 0.4196078431, alpha: 1))
        case .pop:
            return literal(#colorLiteral(red: 0.3607843137, green: 0.3529411765, blue: 0.4392156863, alpha: 1))
        case .sakura:
            return literal(#colorLiteral(red: 0.5411764706, green: 0.3607843137, blue: 0.4470588235, alpha: 1))
        case .aqua:
            return literal(#colorLiteral(red: 0.4156862745, green: 0.4784313725, blue: 0.5882352941, alpha: 1))
        case .mori:
            return literal(#colorLiteral(red: 0.368627451, green: 0.431372549, blue: 0.3764705882, alpha: 1))
        case .dark, .elegant:
            return literal(#colorLiteral(red: 0.9215686275, green: 0.9215686275, blue: 0.9607843137, alpha: 1)).opacity(0.62)
        case .system:
            return literal(#colorLiteral(red: 0.4196078431, green: 0.4196078431, blue: 0.4196078431, alpha: 1))
        }
    }
    
    static func textTimelineItem(palette: AppPalette, environmentScheme: ColorScheme) -> Color {
        switch resolvedPalette(palette, environmentScheme: environmentScheme) {
        case .light:
            return Color.white
        case .dark, .elegant:
            return Color.white
        case .pop:
            return literal(#colorLiteral(red: 0.3607843137, green: 0.3529411765, blue: 0.4392156863, alpha: 1))
        case .sakura:
            return Color.white
        case .aqua:
            return Color.white
        case .mori:
            return Color.white
        case .system:
            return literal(#colorLiteral(red: 0.4196078431, green: 0.4196078431, blue: 0.4196078431, alpha: 1))
        }
    }
    
    /// 強い差し色の中のテキスト
    static func strongAccentInsideText(palette: AppPalette, environmentScheme: ColorScheme) -> Color {
        switch resolvedPalette(palette, environmentScheme: environmentScheme) {
        case .light, .pop:
            return Color.white
        case .dark, .elegant:
            return literal(#colorLiteral(red: 0.1098039216, green: 0.1098039216, blue: 0.1176470588, alpha: 1))
        case .sakura:
            return Color.white
        case .aqua:
            return literal(#colorLiteral(red: 0.1843137255, green: 0.2352941176, blue: 0.3333333333, alpha: 1))
        case .mori:
            return Color.white
        case .system:
            return literal(#colorLiteral(red: 0.0666666667, green: 0.0666666667, blue: 0.0666666667, alpha: 1))
        }
    }
    
    /// 強い差し色
    static func strongAccent(palette: AppPalette, environmentScheme: ColorScheme) -> Color {
        switch resolvedPalette(palette, environmentScheme: environmentScheme) {
        case .light:
            return Color.red
        case .dark:
            return literal(#colorLiteral(red: 0.8386453986, green: 0.5495020747, blue: 0.1809690893, alpha: 1))
        case .pop:
            return literal(#colorLiteral(red: 0.4784313725, green: 0.4352941176, blue: 0.9411764706, alpha: 1))
        case .elegant:
            return literal(#colorLiteral(red: 0.9019607843, green: 0.8274509804, blue: 0.6470588235, alpha: 1))
        case .sakura:
            return literal(#colorLiteral(red: 0.8470588235, green: 0.1058823529, blue: 0.3764705882, alpha: 1))
        case .aqua:
            return literal(#colorLiteral(red: 0.4901960784, green: 0.6823529412, blue: 0.9607843137, alpha: 1))
        case .mori:
            return literal(#colorLiteral(red: 0.4352941176, green: 0.5607843137, blue: 0.4431372549, alpha: 1))
        case .system:
            return Color.black
        }
    }

    /// アクセント（ボタンや強調）
    static func accent(palette: AppPalette, environmentScheme: ColorScheme) -> Color {
        switch resolvedPalette(palette, environmentScheme: environmentScheme) {
        case .light:
            return literal(#colorLiteral(red: 0.7803921569, green: 0.3058823529, blue: 0.3529411765, alpha: 1))
        case .dark:
            return literal(#colorLiteral(red: 0.831372549, green: 0.6039215686, blue: 0.3529411765, alpha: 1))
        case .pop:
            return literal(#colorLiteral(red: 0.4784313725, green: 0.4352941176, blue: 0.9411764706, alpha: 1))
        case .elegant:
            return literal(#colorLiteral(red: 0.9019607843, green: 0.8274509804, blue: 0.6470588235, alpha: 1))
        case .sakura:
            return literal(#colorLiteral(red: 0.9254901961, green: 0.2509803922, blue: 0.4784313725, alpha: 1))
        case .aqua:
            return literal(#colorLiteral(red: 0.5764705882, green: 0.7607843137, blue: 1, alpha: 1))
        case .mori:
            return literal(#colorLiteral(red: 0.5607843137, green: 0.6784313725, blue: 0.5647058824, alpha: 1))
        case .system:
            return Color.black
        }
    }
    
    static func primary(palette: AppPalette, environmentScheme: ColorScheme) -> Color {
        switch resolvedPalette(palette, environmentScheme: environmentScheme) {
        case .light, .pop:
            return literal(#colorLiteral(red: 0.2196078431, green: 0.2196078431, blue: 0.2196078431, alpha: 1))
        case .dark, .elegant:
            return Color.primary.opacity(0.9)
        case .sakura:
            return literal(#colorLiteral(red: 0.5098039216, green: 0.3529411765, blue: 0.4117647059, alpha: 1))
        case .aqua:
            return literal(#colorLiteral(red: 0.1843137255, green: 0.2352941176, blue: 0.3333333333, alpha: 1))
        case .mori:
            return literal(#colorLiteral(red: 0.1803921569, green: 0.2274509804, blue: 0.1843137255, alpha: 1))
        case .system:
            return literal(#colorLiteral(red: 0.0666666667, green: 0.0666666667, blue: 0.0666666667, alpha: 1))
        }
    }

    /// `accent` の上に載せるアイコン/テキスト色（視認性優先で白/黒に寄せる）
    static func onAccent(palette: AppPalette, environmentScheme: ColorScheme) -> Color {
        switch resolvedPalette(palette, environmentScheme: environmentScheme) {
        case .light:
            return Color.white
        case .dark:
            return Color.black
        case .pop:
            return Color.white
        case .elegant:
            return Color.black
        case .sakura:
            return Color.white
        case .aqua:
            return Color.white
        case .mori:
            return Color.white
        case .system:
            return Color.white
        }
    }

    /// 仮配置カードの背景（タイムライン上でドロップ前の入力カード）
    static func pendingCardBackground(palette: AppPalette, environmentScheme: ColorScheme) -> Color {
        switch resolvedPalette(palette, environmentScheme: environmentScheme) {
        case .light:
            return literal(#colorLiteral(red: 0.2196078431, green: 0.2196078431, blue: 0.2196078431, alpha: 1)).opacity(0.9)
        case .dark:
            return literal(#colorLiteral(red: 0.2823529412, green: 0.2823529412, blue: 0.2901960784, alpha: 1)).opacity(0.95)
        case .pop:
            return literal(#colorLiteral(red: 0.1725490196, green: 0.1647058824, blue: 0.2509803922, alpha: 1)).opacity(0.92)
        case .elegant:
            return literal(#colorLiteral(red: 0.1647058824, green: 0.1647058824, blue: 0.1803921569, alpha: 1)).opacity(0.95)
        case .sakura:
            return literal(#colorLiteral(red: 0.6509803922, green: 0.3019607843, blue: 0.4745098039, alpha: 1)).opacity(0.92)
        case .aqua:
            return literal(#colorLiteral(red: 0.2039215686, green: 0.3137254902, blue: 0.4862745098, alpha: 1)).opacity(0.9)
        case .mori:
            return literal(#colorLiteral(red: 0.2431372549, green: 0.3215686275, blue: 0.2509803922, alpha: 1)).opacity(0.92)
        case .system:
            return literal(#colorLiteral(red: 0.2196078431, green: 0.2196078431, blue: 0.2196078431, alpha: 1)).opacity(0.9)
        }
    }
    
    /// 仮配置カードのストローク
    static func pendingCardStroke(palette: AppPalette, environmentScheme: ColorScheme) -> Color {
        switch resolvedPalette(palette, environmentScheme: environmentScheme) {
        case .dark, .elegant:
            return Color.white.opacity(0.35)
        default:
            return Color.white.opacity(0.6)
        }
    }
    
    /// タイムライン項目カードのベース色（複数色を返して分散させる）
    static func itemCardColors(palette: AppPalette, environmentScheme: ColorScheme) -> [Color] {
        switch resolvedPalette(palette, environmentScheme: environmentScheme) {
        case .light:
            return [literal(#colorLiteral(red: 0.2196078431, green: 0.2196078431, blue: 0.2196078431, alpha: 1))]
        case .dark:
            return [literal(#colorLiteral(red: 0.8039215803, green: 0.8039215803, blue: 0.8039215803, alpha: 1))]
        case .elegant:
            return [
                literal(#colorLiteral(red: 0.1647058824, green: 0.1411764706, blue: 0.1254901961, alpha: 1)),
                literal(#colorLiteral(red: 0.1411764706, green: 0.1411764706, blue: 0.1568627451, alpha: 1)),
                literal(#colorLiteral(red: 0.1215686275, green: 0.1215686275, blue: 0.1411764706, alpha: 1))
            ]
        case .pop:
            return [
                literal(#colorLiteral(red: 0.4784313725, green: 0.4352941176, blue: 0.9411764706, alpha: 1)),
                literal(#colorLiteral(red: 0.9411764706, green: 0.5607843137, blue: 0.6941176471, alpha: 1)),
                literal(#colorLiteral(red: 0.3568627451, green: 0.7294117647, blue: 0.8392156863, alpha: 1))
            ]
        case .sakura:
            return [literal(#colorLiteral(red: 0.9098039269, green: 0.4784313738, blue: 0.6431372762, alpha: 1)),
//                    literal(#colorLiteral(red: 0.9568627451, green: 0.5607843137, blue: 0.6941176471, alpha: 1)),
//                    literal(#colorLiteral(red: 0.8078431373, green: 0.5764705882, blue: 0.8470588235, alpha: 1))
            ]
        case .aqua:
            return [
                literal(#colorLiteral(red: 0.4901960784, green: 0.6823529412, blue: 0.9607843137, alpha: 1)),
//                literal(#colorLiteral(red: 0.6078431373, green: 0.768627451, blue: 1, alpha: 1)),
//                literal(#colorLiteral(red: 0.431372549, green: 0.6352941176, blue: 0.9254901961, alpha: 1))
            ]
        case .mori:
            return [
                literal(#colorLiteral(red: 0.4352941176, green: 0.5607843137, blue: 0.4431372549, alpha: 1)),
//                literal(#colorLiteral(red: 0.5607843137, green: 0.6784313725, blue: 0.5647058824, alpha: 1)),
//                literal(#colorLiteral(red: 0.3725490196, green: 0.4823529412, blue: 0.3882352941, alpha: 1))
            ]
        case .system:
            return [literal(#colorLiteral(red: 0.2196078431, green: 0.2196078431, blue: 0.2196078431, alpha: 1))]
        }
    }
    
    // 配置カードのストローク
    static func cardStroke(palette: AppPalette, environmentScheme: ColorScheme) -> Color {
        switch resolvedPalette(palette, environmentScheme: environmentScheme) {
        case .light:
            return literal(#colorLiteral(red: 0.9725490196, green: 0.9725490196, blue: 0.9725490196, alpha: 1))
        case .dark:
            return literal(#colorLiteral(red: 0.1098039216, green: 0.1098039216, blue: 0.1176470588, alpha: 1))
        case .elegant:
            return Color.white.opacity(0.35)
        case .sakura:
            return literal(#colorLiteral(red: 0.9921568627, green: 0.9137254902, blue: 0.9450980392, alpha: 1))
        case .aqua:
            return literal(#colorLiteral(red: 0.8980392157, green: 0.9411764706, blue: 1, alpha: 1))
        case .mori:
            return literal(#colorLiteral(red: 0.8666666667, green: 0.9098039216, blue: 0.8549019608, alpha: 1))
        case .pop:
            return Color.white.opacity(0.6)
        case .system:
            return Color.white.opacity(0.6)
        default:
            return Color.white.opacity(0.6)
        }
    }

    /// グリッド線（タイムラインの時間軸の線）
    static func gridLine(palette: AppPalette, environmentScheme: ColorScheme) -> Color {
        switch resolvedPalette(palette, environmentScheme: environmentScheme) {
        case .dark, .elegant:
            return Color.white.opacity(0.12)
        case .sakura:
            return literal(#colorLiteral(red: 0.6588235294, green: 0.3019607843, blue: 0.4509803922, alpha: 1)).opacity(0.16)
        case .aqua:
            return literal(#colorLiteral(red: 0.3725490196, green: 0.5607843137, blue: 0.8392156863, alpha: 1)).opacity(0.16)
        case .mori:
            return literal(#colorLiteral(red: 0.4156862745, green: 0.5137254902, blue: 0.4274509804, alpha: 1)).opacity(0.18)
        default:
            return Color.black.opacity(0.1)
        }
    }

    /// 設定リスト行の背景（画面背景より少し薄い色）
    static func settingsListBackground(palette: AppPalette, environmentScheme: ColorScheme) -> Color {
        switch resolvedPalette(palette, environmentScheme: environmentScheme) {
        case .light:
            return literal(#colorLiteral(red: 0.9803921569, green: 0.9803921569, blue: 0.9803921569, alpha: 1))
        case .dark:
            return literal(#colorLiteral(red: 0.1647058824, green: 0.1647058824, blue: 0.1725490196, alpha: 1))
        case .pop:
            return literal(#colorLiteral(red: 1, green: 1, blue: 1, alpha: 1))
        case .elegant:
            return literal(#colorLiteral(red: 0.1137254902, green: 0.1137254902, blue: 0.1254901961, alpha: 1))
        case .sakura:
            return literal(#colorLiteral(red: 1, green: 0.9529411765, blue: 0.9725490196, alpha: 1))
        case .aqua:
            return literal(#colorLiteral(red: 0.9725490196, green: 0.9843137255, blue: 1, alpha: 1))
        case .mori:
            return literal(#colorLiteral(red: 0.9490196078, green: 0.9647058824, blue: 0.9411764706, alpha: 1))
        case .system:
            return literal(#colorLiteral(red: 0.9803921569, green: 0.9803921569, blue: 0.9803921569, alpha: 1))
        }
    }

    /// グリッド面（タイムライン全体の薄い背景）
//    static func gridFill(palette: AppPalette, environmentScheme: ColorScheme) -> Color {
//        switch (palette, environmentScheme) {
//        case (.light, _):
//            return literal(#colorLiteral(red: 0.9725490196, green: 0.9725490196, blue: 0.9725490196, alpha: 1))
//        case (.dark, _):
//            return literal(#colorLiteral(red: 0.1098039216, green: 0.1098039216, blue: 0.1176470588, alpha: 1))
//        case (.pop, _):
//            return literal(#colorLiteral(red: 0.9843137255, green: 0.9803921569, blue: 1, alpha: 1))
//        case (.elegant, _):
//            return literal(#colorLiteral(red: 0.0784313725, green: 0.0784313725, blue: 0.0862745098, alpha: 1))
//        case (.system, .light):
//            return literal(#colorLiteral(red: 0.9725490196, green: 0.9725490196, blue: 0.9725490196, alpha: 1))
//        case (.system, .dark):
//            return literal(#colorLiteral(red: 0.1098039216, green: 0.1098039216, blue: 0.1176470588, alpha: 1))
//        @unknown default:
//            return literal(#colorLiteral(red: 0.9725490196, green: 0.9725490196, blue: 0.9725490196, alpha: 1))
//        }
//    }

    // MARK: - 既存 API（環境の ColorScheme をそのまま使う）

    static func background(for scheme: ColorScheme) -> Color { background(palette: .system, environmentScheme: scheme) }
//    static func surface(for scheme: ColorScheme) -> Color { surface(palette: .system, environmentScheme: scheme) }
    static func shadow(for scheme: ColorScheme) -> Color { shadow(palette: .system, environmentScheme: scheme) }
//    static func divider(for scheme: ColorScheme) -> Color { divider(palette: .system, environmentScheme: scheme) }
    static func textPrimary(for scheme: ColorScheme) -> Color { textPrimary(palette: .system, environmentScheme: scheme) }
    static func textSecondary(for scheme: ColorScheme) -> Color { textSecondary(palette: .system, environmentScheme: scheme) }
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
    static var textSecondary: Color { textSecondary(for: .light) }
//    static var divider: Color { divider(for: .light) }
    static var accent: Color { accent(for: .light) }
}
