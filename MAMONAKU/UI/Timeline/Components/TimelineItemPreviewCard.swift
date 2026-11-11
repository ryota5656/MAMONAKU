import SwiftUI

/// 操作中の予定の「置かれる場所」を示す半透明のカード（ドロップ先・リサイズ中・長押しで作成中）。
struct TimelineItemPreviewCard: View {
    /// 表示する時間帯（例: "09:00 - 10:30"）
    let timeRangeText: String
    let color: Color

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)

        Text(timeRangeText)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white.opacity(0.9))
            .padding(.leading, 15)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(shape.fill(color.opacity(0.35)))
            .clipShape(shape)
            .overlay(
                shape.stroke(Color.white.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
            )
    }
}

extension TimelineItemPreviewCard {
    /// 予定の時間帯と、その予定に割り当てられた色で表示する。
    init(item: TimelineItem, theme: AppTheme) {
        self.init(
            timeRangeText: item.startMinutes.map {
                DayTime.rangeText(startMinutes: $0, durationMinutes: item.durationMinutes)
            } ?? "",
            color: theme.itemCardColor(for: item.id)
        )
    }
}

#Preview {
    TimelineItemPreviewCard(timeRangeText: "11:00 - 11:15", color: AppTheme.light.itemCardColor)
        .frame(height: 50)
        .padding(.horizontal, 20)
}
