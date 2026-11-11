import SwiftUI

/// 次の予定の開始時刻とタイトルを示すカード。次の予定が無ければ何も表示しない。
struct CountdownNextInfoCard: View {
    @Environment(\.appTheme) private var theme
    let next: TimelineItem?

    var body: some View {
        if let next {
            VStack(alignment: .leading, spacing: 6) {
                Text(DayTime.clockText(minutes: next.startMinutes ?? 0))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(theme.textSecondary)
                Text(next.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(theme.textSecondary)
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
}

#Preview("CountdownNextInfoCard") {
    CountdownNextInfoCard(
        next: TimelineItem(title: "Study", durationMinutes: 60, startMinutes: 9 * 60 + 30, dropDate: Date())
    )
    .padding()
}
