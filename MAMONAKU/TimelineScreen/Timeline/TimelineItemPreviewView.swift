import SwiftUI

struct ScheduleItemPreviewView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    let item: TimelineItem
    let showTimeRange: Bool

    private let cornerRadius: CGFloat = 12
    private let leftBarWidth: CGFloat = 6

    private var cardColor: Color {
        let colors = AppColors.itemCardColors(palette: themeManager.theme, environmentScheme: colorScheme)
        let index = abs(item.id.hashValue) % max(colors.count, 1)
        return colors[min(index, colors.count - 1)]
    }

    private var startTimeText: String {
        guard let start = item.startMinutes else { return "" }
        let h = start / 60
        let m = start % 60
        return String(format: "%02d:%02d", h, m)
    }

    private var endTimeText: String {
        guard let start = item.startMinutes else { return "" }
        let end = start + item.durationMinutes
        let h = (end / 60) % 24
        let m = end % 60
        return String(format: "%02d:%02d", h, m)
    }

    private var timeRangeText: String {
        guard !startTimeText.isEmpty else { return "" }
        return "\(startTimeText) - \(endTimeText)"
    }

    var body: some View {
        HStack(spacing: 0) {
//            RoundedRectangle(cornerRadius: 3)
//                .fill(Color.white.opacity(0.5))
//                .frame(width: leftBarWidth)
//                .padding(15)

            VStack(alignment: .leading, spacing: 6) {
                Text(showTimeRange ? timeRangeText : startTimeText)
                    .font(.system(size: showTimeRange ? 12 : 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.leading, 15)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(cardColor.opacity(0.35))
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
        )
    }
}

#Preview {
    ScheduleItemPreviewView(item:
        TimelineItem(title: "Wake up", durationMinutes: 15, startMinutes: 11 * 60, dropDate: Date()),
        showTimeRange: true
    )
    .frame(height: 50)
    .padding(.horizontal, 20)
    .environmentObject(ThemeManager())
}
