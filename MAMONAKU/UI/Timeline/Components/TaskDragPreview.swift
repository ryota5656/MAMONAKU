import SwiftUI

struct TaskDragPreview: View {
    @Environment(\.colorScheme) private var colorScheme
    let item: TimelineItem
    let height: CGFloat

    var body: some View {
        let accent = Color.accentColor
        let shadow = colorScheme == .dark ? Color.black.opacity(0.35) : Color.black.opacity(0.15)
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(accent)
                .frame(width: 6)
                .frame(maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
                Text("\(item.durationMinutes) min")
                    .font(.system(size: 10))
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
                Spacer(minLength: 0)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .frame(width: 180, height: height)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: shadow, radius: 10, x: 0, y: 6)
        )
    }
}

#Preview("TaskDragPreview") {
    TaskDragPreview(
        item: TimelineItem(title: "プレビュー", durationMinutes: 30),
        height: 100
    )
    .padding()
}

