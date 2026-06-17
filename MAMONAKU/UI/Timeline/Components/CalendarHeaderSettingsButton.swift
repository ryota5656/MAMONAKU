import SwiftUI

struct CalendarHeaderSettingsButton: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    var isHighlighted: Bool = false
    var onTap: () -> Void = {}
    @State private var pulse: Bool = false

    var body: some View {
        let secondary = AppColors.textSecondary(palette: themeManager.theme, environmentScheme: colorScheme)
        let strongAccent = AppColors.strongAccent(palette: themeManager.theme, environmentScheme: colorScheme)

        Button(action: onTap) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(secondary)
                .frame(width: 30, height: 30)
                .background(
                    Circle()
                        .fill(AppColors.settingsListBackground(palette: themeManager.theme, environmentScheme: colorScheme))
                )
                .overlay {
                    if isHighlighted {
                        Circle()
                            .stroke(strongAccent, lineWidth: 3)
                            .scaleEffect(pulse ? 1.35 : 1.05)
                            .opacity(pulse ? 0.2 : 0.9)
                            .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)
                            .onAppear { pulse = true }
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

#Preview("SettingsButton") {
    CalendarHeaderSettingsButton()
        .padding()
        .background(Color(.systemBackground))
        .environmentObject(ThemeManager())
}

#Preview("SettingsButton - Highlighted") {
    CalendarHeaderSettingsButton(isHighlighted: true)
        .padding()
        .background(Color(.systemBackground))
        .environmentObject(ThemeManager())
}
