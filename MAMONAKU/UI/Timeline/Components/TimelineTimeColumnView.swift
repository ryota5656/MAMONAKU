import SwiftUI

/// タイムライン左端の時刻ラベル列（00:00〜24:00）。
struct TimelineTimeColumnView: View {
    @Environment(\.appTheme) private var theme
    let layout: TimelineLayout

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0...24, id: \.self) { hour in
                Text(String(format: "%02d:00", hour))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(theme.textSecondary)
                    .frame(
                        width: TimelineLayout.timeColumnWidth,
                        height: layout.hourHeight,
                        alignment: .topLeading
                    )
            }
        }
    }
}

#Preview("TimelineTimeColumnView") {
    ScrollView {
        TimelineTimeColumnView(layout: TimelineLayout())
            .padding()
    }
}
