import SwiftUI

/// 現在時刻を示す横線と時刻ラベル。時間の経過に合わせて位置が動く。
struct TimelineCurrentTimeLineView: View {
    @Environment(\.appTheme) private var theme
    let width: CGFloat
    let layout: TimelineLayout

    var body: some View {
        TimelineView(.animation) { context in
            let minutes = DayTime.minutesSinceMidnight(of: context.date)

            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(theme.strongAccent)
                    .frame(width: width, height: 2)
                    .offset(y: -10)
                Text(DayTime.clockText(minutes: minutes))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(theme.onStrongAccent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(theme.strongAccent)
                    .cornerRadius(4)
                    .offset(x: 4, y: -20)
            }
            .offset(y: layout.yOffset(forMinutes: minutes))
        }
    }
}

#Preview("TimelineCurrentTimeLineView") {
    TimelineCurrentTimeLineView(width: 240, layout: TimelineLayout())
        .frame(height: TimelineLayout().dayHeight, alignment: .top)
        .padding()
}
