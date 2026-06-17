import SwiftUI

struct AllDayTagRowView: View {
    let items: [TimelineItem]
    let timeColumnWidth: CGFloat
    let textColor: Color
    let chipBackground: Color

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Color.clear
                .frame(width: timeColumnWidth)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(items) { item in
                        Text(item.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(textColor)
                            .lineLimit(1)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(chipBackground)
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
        ],
        timeColumnWidth: 52,
        textColor: .primary,
        chipBackground: Color.primary.opacity(0.06)
    )
    .padding()
}

