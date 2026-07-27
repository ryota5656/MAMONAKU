import SwiftUI

/// タイムライン画面のカウントダウン用プログレスバー（残り1時間の進捗を表示）
struct TimelineCountdownProgressBar: View {
    let secondsRemaining: Int
    let accent: Color

    private var clampedSeconds: Int {
        max(0, min(3600, secondsRemaining))
    }

    private var progress: CGFloat {
        1.0 - (CGFloat(clampedSeconds) / 3600.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { proxy in
                let width = proxy.size.width
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.06))
                    Capsule()
                        .fill(accent)
                        .frame(width: max(6, width * progress))
                    HStack(spacing: 0) {
                        ForEach(0..<5, id: \.self) { _ in
                            Circle()
                                .fill(accent)
                                .frame(width: 6, height: 6)
                                .opacity(0.15)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
            .frame(height: 20)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("CountdownProgressBar") {
    TimelineCountdownProgressBar(secondsRemaining: 12 * 60 + 34, accent: .primary)
        .padding()
}

