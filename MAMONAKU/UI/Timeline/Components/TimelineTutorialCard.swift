import SwiftUI

/// 初回チュートリアルの案内カード。
struct TimelineTutorialCard: View {
    @Environment(\.appTheme) private var theme
    let step: TimelineTutorialStep
    let onSkip: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)

        VStack(alignment: .leading, spacing: 8) {
            Text("はじめてガイド")
                .font(.caption.weight(.bold))
                .foregroundStyle(theme.textSecondary)
            Text(step.message)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Button("あとで", action: onSkip)
                .font(.caption.weight(.bold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .strokeBorder(theme.textSecondary.opacity(0.35), lineWidth: 1)
                )
                .foregroundStyle(theme.textPrimary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(shape.fill(theme.surface))
        .overlay(shape.stroke(theme.textSecondary.opacity(0.22), lineWidth: 1))
    }
}

#Preview {
    TimelineTutorialCard(step: .placeTaskAfterNow, onSkip: {})
        .padding()
}
