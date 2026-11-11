import SwiftUI

/// 1 日分のタイムラインの下地（背景と 1 時間ごとの目盛り）。
struct TimelineGridView: View {
    @Environment(\.appTheme) private var theme
    let width: CGFloat
    let layout: TimelineLayout

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(theme.background)
                .frame(width: width, height: layout.dayHeight)

            ForEach(0...24, id: \.self) { hour in
                Rectangle()
                    .fill(theme.gridLine)
                    .frame(width: 10, height: 1)
                    .offset(y: CGFloat(hour) * layout.hourHeight)
            }
        }
    }
}

#Preview("TimelineGridView") {
    ScrollView {
        TimelineGridView(width: 260, layout: TimelineLayout())
            .padding()
    }
}
