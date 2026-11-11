import SwiftUI

/// 無料版と PLUS の機能差を並べたカード。
struct SubscriptionFeatureComparisonCard: View {
    @Environment(\.appTheme) private var theme

    private struct Feature: Identifiable {
        let title: String
        let free: String
        let plus: String
        var id: String { title }
    }

    private static let features = [
        Feature(title: "テーマ選択", free: "System / Light / Dark", plus: "全テーマ利用"),
        Feature(title: "標準カレンダー同期", free: "利用不可", plus: "利用可能"),
        Feature(title: "開始通知", free: "オン/オフ", plus: "オン/オフ"),
        Feature(title: "複数Live Activity表示", free: "利用不可", plus: "オン/オフ"),
        Feature(title: "バッファ通知", free: "利用不可", plus: "オン/オフ + 分数設定"),
        Feature(title: "優先度設定", free: "Lowのみ", plus: "Low / Medium / High")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Self.features) { feature in
                HStack(alignment: .firstTextBaseline) {
                    Text(feature.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.textPrimary)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("無料: \(feature.free)")
                            .font(.caption)
                            .foregroundStyle(theme.textSecondary)
                        Text("PLUS: \(feature.plus)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.textPrimary)
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)
                .fill(theme.surface)
        )
    }
}

#Preview {
    SubscriptionFeatureComparisonCard()
        .padding()
}
