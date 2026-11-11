import SwiftUI
import UIKit

/// テーマごとの配色定義。色を調整するときはここだけを編集する。
extension AppTheme {
    static let light = AppTheme(
        background: color(#colorLiteral(red: 0.9529411765, green: 0.9529411765, blue: 0.9529411765, alpha: 1)),
        surface: color(#colorLiteral(red: 0.9803921569, green: 0.9803921569, blue: 0.9803921569, alpha: 1)),
        shadow: color(#colorLiteral(red: 0.7098039216, green: 0.7294117647, blue: 0.8078431373, alpha: 1)).opacity(0.5),
        textPrimary: color(#colorLiteral(red: 0.2196078431, green: 0.2196078431, blue: 0.2196078431, alpha: 1)),
        textSecondary: color(#colorLiteral(red: 0.4196078431, green: 0.4196078431, blue: 0.4196078431, alpha: 1)),
        accent: color(#colorLiteral(red: 0.7803921569, green: 0.3058823529, blue: 0.3529411765, alpha: 1)),
        onAccent: .white,
        strongAccent: .red,
        onStrongAccent: .white,
        gridLine: Color.black.opacity(0.1),
        itemCardColors: [color(#colorLiteral(red: 0.2196078431, green: 0.2196078431, blue: 0.2196078431, alpha: 1))]
    )

    static let dark = AppTheme(
        background: color(#colorLiteral(red: 0.1098039216, green: 0.1098039216, blue: 0.1176470588, alpha: 1)),
        surface: color(#colorLiteral(red: 0.1647058824, green: 0.1647058824, blue: 0.1725490196, alpha: 1)),
        shadow: Color.black.opacity(0.35),
        textPrimary: Color.primary.opacity(0.9),
        textSecondary: color(#colorLiteral(red: 0.9215686275, green: 0.9215686275, blue: 0.9607843137, alpha: 1)).opacity(0.62),
        accent: color(#colorLiteral(red: 0.831372549, green: 0.6039215686, blue: 0.3529411765, alpha: 1)),
        onAccent: .black,
        strongAccent: color(#colorLiteral(red: 0.8386453986, green: 0.5495020747, blue: 0.1809690893, alpha: 1)),
        onStrongAccent: color(#colorLiteral(red: 0.1098039216, green: 0.1098039216, blue: 0.1176470588, alpha: 1)),
        gridLine: Color.white.opacity(0.12),
        itemCardColors: [color(#colorLiteral(red: 0.8039215803, green: 0.8039215803, blue: 0.8039215803, alpha: 1))]
    )

    static let pop = AppTheme(
        background: color(#colorLiteral(red: 0.9843137255, green: 0.9803921569, blue: 1, alpha: 1)),
        surface: color(#colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)),
        shadow: color(#colorLiteral(red: 0.7490196078, green: 0.7764705882, blue: 0.9019607843, alpha: 1)).opacity(0.42),
        textPrimary: color(#colorLiteral(red: 0.2196078431, green: 0.2196078431, blue: 0.2196078431, alpha: 1)),
        textSecondary: color(#colorLiteral(red: 0.3607843137, green: 0.3529411765, blue: 0.4392156863, alpha: 1)),
        accent: color(#colorLiteral(red: 0.4784313725, green: 0.4352941176, blue: 0.9411764706, alpha: 1)),
        onAccent: .white,
        strongAccent: color(#colorLiteral(red: 0.4784313725, green: 0.4352941176, blue: 0.9411764706, alpha: 1)),
        onStrongAccent: .white,
        gridLine: Color.black.opacity(0.1),
        itemCardColors: [
            color(#colorLiteral(red: 0.4784313725, green: 0.4352941176, blue: 0.9411764706, alpha: 1)),
            color(#colorLiteral(red: 0.9411764706, green: 0.5607843137, blue: 0.6941176471, alpha: 1)),
            color(#colorLiteral(red: 0.3568627451, green: 0.7294117647, blue: 0.8392156863, alpha: 1))
        ]
    )

    static let elegant = AppTheme(
        background: color(#colorLiteral(red: 0.0784313725, green: 0.0784313725, blue: 0.0862745098, alpha: 1)),
        surface: color(#colorLiteral(red: 0.1137254902, green: 0.1137254902, blue: 0.1254901961, alpha: 1)),
        shadow: Color.black.opacity(0.45),
        textPrimary: Color.primary.opacity(0.9),
        textSecondary: color(#colorLiteral(red: 0.9215686275, green: 0.9215686275, blue: 0.9607843137, alpha: 1)).opacity(0.62),
        accent: color(#colorLiteral(red: 0.9019607843, green: 0.8274509804, blue: 0.6470588235, alpha: 1)),
        onAccent: .black,
        strongAccent: color(#colorLiteral(red: 0.9019607843, green: 0.8274509804, blue: 0.6470588235, alpha: 1)),
        onStrongAccent: color(#colorLiteral(red: 0.1098039216, green: 0.1098039216, blue: 0.1176470588, alpha: 1)),
        gridLine: Color.white.opacity(0.12),
        itemCardColors: [
            color(#colorLiteral(red: 0.1647058824, green: 0.1411764706, blue: 0.1254901961, alpha: 1)),
            color(#colorLiteral(red: 0.1411764706, green: 0.1411764706, blue: 0.1568627451, alpha: 1)),
            color(#colorLiteral(red: 0.1215686275, green: 0.1215686275, blue: 0.1411764706, alpha: 1))
        ]
    )

    static let sakura = AppTheme(
        background: color(#colorLiteral(red: 0.9921568627, green: 0.9137254902, blue: 0.9450980392, alpha: 1)),
        surface: color(#colorLiteral(red: 1, green: 0.9529411765, blue: 0.9725490196, alpha: 1)),
        shadow: color(#colorLiteral(red: 0.831372549, green: 0.6039215686, blue: 0.7058823529, alpha: 1)).opacity(0.45),
        textPrimary: color(#colorLiteral(red: 0.5098039216, green: 0.3529411765, blue: 0.4117647059, alpha: 1)),
        textSecondary: color(#colorLiteral(red: 0.5411764706, green: 0.3607843137, blue: 0.4470588235, alpha: 1)),
        accent: color(#colorLiteral(red: 0.9254901961, green: 0.2509803922, blue: 0.4784313725, alpha: 1)),
        onAccent: .white,
        strongAccent: color(#colorLiteral(red: 0.8470588235, green: 0.1058823529, blue: 0.3764705882, alpha: 1)),
        onStrongAccent: .white,
        gridLine: color(#colorLiteral(red: 0.6588235294, green: 0.3019607843, blue: 0.4509803922, alpha: 1)).opacity(0.16),
        itemCardColors: [color(#colorLiteral(red: 0.9098039269, green: 0.4784313738, blue: 0.6431372762, alpha: 1))]
    )

    static let aqua = AppTheme(
        background: color(#colorLiteral(red: 0.9490196078, green: 0.968627451, blue: 1, alpha: 1)),
        surface: color(#colorLiteral(red: 0.9725490196, green: 0.9843137255, blue: 1, alpha: 1)),
        shadow: color(#colorLiteral(red: 0.7176470588, green: 0.7882352941, blue: 0.9098039216, alpha: 1)).opacity(0.45),
        textPrimary: color(#colorLiteral(red: 0.1843137255, green: 0.2352941176, blue: 0.3333333333, alpha: 1)),
        textSecondary: color(#colorLiteral(red: 0.4156862745, green: 0.4784313725, blue: 0.5882352941, alpha: 1)),
        accent: color(#colorLiteral(red: 0.5764705882, green: 0.7607843137, blue: 1, alpha: 1)),
        onAccent: .white,
        strongAccent: color(#colorLiteral(red: 0.4901960784, green: 0.6823529412, blue: 0.9607843137, alpha: 1)),
        onStrongAccent: color(#colorLiteral(red: 0.1843137255, green: 0.2352941176, blue: 0.3333333333, alpha: 1)),
        gridLine: color(#colorLiteral(red: 0.3725490196, green: 0.5607843137, blue: 0.8392156863, alpha: 1)).opacity(0.16),
        itemCardColors: [color(#colorLiteral(red: 0.4901960784, green: 0.6823529412, blue: 0.9607843137, alpha: 1))]
    )

    static let mori = AppTheme(
        background: color(#colorLiteral(red: 0.9176470588, green: 0.9411764706, blue: 0.9019607843, alpha: 1)),
        surface: color(#colorLiteral(red: 0.9490196078, green: 0.9647058824, blue: 0.9411764706, alpha: 1)),
        shadow: color(#colorLiteral(red: 0.6196078431, green: 0.6980392157, blue: 0.6156862745, alpha: 1)).opacity(0.45),
        textPrimary: color(#colorLiteral(red: 0.1803921569, green: 0.2274509804, blue: 0.1843137255, alpha: 1)),
        textSecondary: color(#colorLiteral(red: 0.368627451, green: 0.431372549, blue: 0.3764705882, alpha: 1)),
        accent: color(#colorLiteral(red: 0.5607843137, green: 0.6784313725, blue: 0.5647058824, alpha: 1)),
        onAccent: .white,
        strongAccent: color(#colorLiteral(red: 0.4352941176, green: 0.5607843137, blue: 0.4431372549, alpha: 1)),
        onStrongAccent: .white,
        gridLine: color(#colorLiteral(red: 0.4156862745, green: 0.5137254902, blue: 0.4274509804, alpha: 1)).opacity(0.18),
        itemCardColors: [color(#colorLiteral(red: 0.4352941176, green: 0.5607843137, blue: 0.4431372549, alpha: 1))]
    )

    private static func color(_ uiColor: UIColor) -> Color {
        Color(uiColor: uiColor)
    }
}
