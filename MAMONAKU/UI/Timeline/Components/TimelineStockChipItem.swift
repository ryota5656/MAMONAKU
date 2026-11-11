import SwiftUI

/// Stock に並ぶタスク 1 件（優先度・タイトル・所要時間）。
/// タップやドラッグは、これを並べる `TimelineStockChipList` 側で扱う。
struct TimelineStockChipItem: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    let item: TimelineItem

    var body: some View {
        let priorityColor = theme.priorityColor(item.priority)

        HStack(spacing: 6) {
            PriorityIconView(priority: item.priority, color: priorityColor, size: 13)

            Text(item.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.textPrimary)
                .lineLimit(1)

            Text("\(item.durationMinutes)m")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(theme.textSecondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    Capsule(style: .continuous)
                        .fill(durationBadgeFill)
                )
        }
        .padding(.leading, 11)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .background {
            Capsule(style: .continuous)
                .fill(chipFill)
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(priorityColor.opacity(isDark ? 0.35 : 0.28), lineWidth: 1)
                }
                .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 1)
        }
        .contentShape(Capsule())
    }

    private var isDark: Bool {
        colorScheme == .dark
    }

    /// 半透明のガラス面（Stock カード）の上でも沈まない、明るいフロスト面
    private var chipFill: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(isDark ? 0.28 : 0.92),
                Color.white.opacity(isDark ? 0.16 : 0.72)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var durationBadgeFill: Color {
        isDark ? Color.white.opacity(0.14) : Color.black.opacity(0.05)
    }
}

#Preview("TimelineStockChipItem") {
    ZStack {
        LinearGradient(
            colors: [Color.blue.opacity(0.4), Color.teal.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        HStack(spacing: 8) {
            TimelineStockChipItem(item: TimelineItem(title: "買い物", durationMinutes: 30))
            TimelineStockChipItem(item: TimelineItem(title: "読書", durationMinutes: 45, priority: .high))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }
}
