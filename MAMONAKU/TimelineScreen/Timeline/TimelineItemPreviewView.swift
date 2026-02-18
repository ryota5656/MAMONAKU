import SwiftUI

struct ScheduleItemPreviewView: View {
    let item: TimelineItem
    let showTimeRange: Bool

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 30)
                .fill(Color.black.opacity(0.3))
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 4) {
                if showTimeRange {
                    Text(TimelineViewModel.timeRangeText(
                        startMinutes: item.startMinutes,
                        durationMinutes: item.durationMinutes
                    ))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 10)
                }
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.black.opacity(0.12), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        )
        .background(Color(.systemBackground).opacity(0.7))
    }
}

#Preview {
    ScheduleItemPreviewView(item:
        TimelineItem(title: "Wake up", durationMinutes: 15, startMinutes: 11 * 60, dropDate: Date()),
        showTimeRange: true
    )
    .frame(height: 50)
    .padding(.horizontal, 20)
}
