import SwiftUI

struct TimelineCurrentTimeLineView: View {
    let width: CGFloat
    let yOffset: (Int) -> CGFloat
    let minutesSinceMidnight: (Date) -> Int
    let currentTimeText: (Date) -> String
    let accent: Color
    let insideText: Color

    var body: some View {
        TimelineView(.animation) { context in
            let minutes = minutesSinceMidnight(context.date)
            let y = yOffset(minutes)

            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(accent)
                    .frame(width: width, height: 2)
                    .offset(y: -10)
                Text(currentTimeText(context.date))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(insideText)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(accent)
                    .cornerRadius(4)
                    .offset(x: 4, y: -20)
            }
            .offset(y: y)
        }
    }
}

#Preview("TimelineCurrentTimeLineView") {
    TimelineCurrentTimeLineView(
        width: 240,
        yOffset: { minutes in CGFloat(minutes) / 60 * 80 },
        minutesSinceMidnight: { date in
            let cal = Calendar.current
            let comps = cal.dateComponents([.hour, .minute], from: date)
            return (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        },
        currentTimeText: { date in
            let cal = Calendar.current
            let comps = cal.dateComponents([.hour, .minute], from: date)
            return String(format: "%02d:%02d", comps.hour ?? 0, comps.minute ?? 0)
        },
        accent: .blue,
        insideText: .white
    )
    .frame(height: 80 * 3)
    .padding()
}

