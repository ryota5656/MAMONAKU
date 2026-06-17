import SwiftUI

struct TutorialOverlayView: View {
    let step: TimelineTutorialStep
    let onAdvance: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        let primary = AppColors.textPrimary(palette: themeManager.theme, environmentScheme: colorScheme)
        let secondary = AppColors.textSecondary(palette: themeManager.theme, environmentScheme: colorScheme)
        let background = AppColors.settingsListBackground(palette: themeManager.theme, environmentScheme: colorScheme)

        VStack(alignment: .leading, spacing: 8) {
            Text("はじめてガイド")
                .font(.caption.weight(.bold))
                .foregroundStyle(secondary)
            Text(step.message)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(primary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                Button(step.primaryButtonTitle, action: onAdvance)
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(AppColors.strongAccent(palette: themeManager.theme, environmentScheme: colorScheme))
                    )
                    .foregroundStyle(Color.white)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(secondary.opacity(0.22), lineWidth: 1)
        )
    }
}
