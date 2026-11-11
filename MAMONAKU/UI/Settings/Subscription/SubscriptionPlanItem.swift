import SwiftUI

/// 購入プラン 1 件分の選択行。
struct SubscriptionPlanItem: View {
    @Environment(\.appTheme) private var theme
    let kind: SubscriptionPlanKind
    let displayName: String
    let displayPrice: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(kind.label)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(theme.textPrimary)
                        if let badge = kind.badge {
                            Text(badge)
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .foregroundStyle(theme.onAccent)
                                .background(Capsule().fill(theme.accent))
                        }
                    }
                    Text(displayName)
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                }
                Spacer()
                Text(displayPrice)
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .foregroundStyle(theme.textPrimary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)
                    .fill(theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)
                    .stroke(
                        isSelected ? theme.accent : theme.textSecondary.opacity(0.25),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack {
        SubscriptionPlanItem(
            kind: .lifetime, displayName: "MAMONAKU PLUS", displayPrice: "¥1,500", isSelected: true, onTap: {}
        )
        SubscriptionPlanItem(
            kind: .monthly, displayName: "MAMONAKU PLUS 月額", displayPrice: "¥200", isSelected: false, onTap: {}
        )
    }
    .padding()
}
