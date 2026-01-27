import SwiftUI

struct ScheduleItemPreviewView: View {
    let item: TimelineItem

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 30)
                .fill(Color.black.opacity(0.3))
                .frame(width: 8)
            VStack(alignment: .leading, spacing: 4) {
                Text(TimelineViewModel.timeRangeText(
                    startMinutes: item.startMinutes,
                    durationMinutes: item.durationMinutes
                ))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Color(.systemBackground).opacity(0.7))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.black.opacity(0.12), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        )
    }

 
}
