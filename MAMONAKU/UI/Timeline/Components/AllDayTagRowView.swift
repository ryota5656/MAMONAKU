import SwiftUI

/// 終日予定をタグとして横に並べる行。タイムラインの時刻列の分だけ左を空ける。
struct AllDayTagRowView: View {
    @Environment(\.appTheme) private var theme
    let items: [TimelineItem]

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Color.clear
                .frame(width: TimelineLayout.timeColumnWidth)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(items) { item in
                        Text(item.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(theme.textPrimary)
                            .lineLimit(1)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(theme.surface)
                            )
                    }
                }
            }
        }
    }
}

#Preview("AllDayTagRowView") {
    AllDayTagRowView(
        items: [
            TimelineItem(title: "終日A", durationMinutes: 30, startMinutes: nil, dropDate: Date(), isAllDay: true),
            TimelineItem(title: "終日B", durationMinutes: 30, startMinutes: nil, dropDate: Date(), isAllDay: true)
        ]
    )
    .padding()
}
