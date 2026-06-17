import SwiftUI

struct CountdownNextInfoCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    let next: TimelineItem?

    var body: some View {
        if let next {
            VStack(alignment: .leading, spacing: 6) {
                Text(minutesToTime(next.startMinutes ?? 0))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary(palette: themeManager.theme, environmentScheme: colorScheme))
                Text(next.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary(palette: themeManager.theme, environmentScheme: colorScheme))
                    .lineLimit(2)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
            )
        }
    }

    private func minutesToTime(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        return String(format: "%02d:%02d", h, m)
    }
}

#Preview("CountdownNextInfoCard") {
    CountdownNextInfoCard(
        next: TimelineItem(title: "Study", durationMinutes: 60, startMinutes: 9 * 60 + 30, dropDate: Date())
    )
    .padding()
    .environmentObject(ThemeManager())
}

#Preview("CountdownNextInfoCard - nil") {
    CountdownNextInfoCard(next: nil)
        .padding()
        .environmentObject(ThemeManager())
}

