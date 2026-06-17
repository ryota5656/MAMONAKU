import SwiftUI

struct TimelineTimeColumnView: View {
    let timeColumnWidth: CGFloat
    let hourHeight: CGFloat
    let zoomScale: CGFloat
    let textColor: Color

    var body: some View {
        let rowHeight = hourHeight * zoomScale
        VStack(spacing: 0) {
            ForEach(0...24, id: \.self) { hour in
                Text(String(format: "%02d:00", hour))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(textColor)
                    .frame(
                        width: timeColumnWidth,
                        height: rowHeight,
                        alignment: .topLeading
                    )
            }
        }
    }
}

#Preview("TimelineTimeColumnView") {
    TimelineTimeColumnView(
        timeColumnWidth: 52,
        hourHeight: 80,
        zoomScale: 1.0,
        textColor: .secondary
    )
    .padding()
}

