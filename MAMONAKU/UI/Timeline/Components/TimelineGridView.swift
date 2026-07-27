import SwiftUI

struct TimelineGridView: View {
    let width: CGFloat
    let height: CGFloat
    let hourHeight: CGFloat
    let zoomScale: CGFloat
    let gridFill: Color
    let gridLine: Color

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(gridFill)
                .frame(width: width, height: height)

            ForEach(0...24, id: \.self) { hour in
                Rectangle()
                    .fill(gridLine)
                    .frame(width: 10, height: 1)
                    .offset(y: CGFloat(hour) * hourHeight * zoomScale)
            }
        }
    }
}

#Preview("TimelineGridView") {
    TimelineGridView(
        width: 260,
        height: 80 * 3,
        hourHeight: 80,
        zoomScale: 1.0,
        gridFill: Color(.systemBackground),
        gridLine: Color.primary.opacity(0.1)
    )
    .padding()
}

