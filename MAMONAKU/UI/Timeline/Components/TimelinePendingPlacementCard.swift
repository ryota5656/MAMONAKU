import SwiftUI

/// 長押しで作った仮配置に、タイトルを入力するカード。表示と同時に入力を始める。
struct TimelinePendingPlacementCard: View {
    @Environment(\.appTheme) private var theme
    @State private var title = ""
    @FocusState private var isFocused: Bool
    let onSubmit: (String) -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)

        TextField("タイトルを入力", text: $title)
            .textFieldStyle(.plain)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(theme.textPrimary)
            .padding(.horizontal, 20)
            .padding(.vertical, 6)
            .submitLabel(.done)
            .onSubmit { onSubmit(title) }
            .focused($isFocused)
            .onAppear { isFocused = true }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(shape.fill(theme.surface))
            .overlay(
                shape.stroke(theme.gridLine, style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
            )
    }
}

#Preview {
    TimelinePendingPlacementCard(onSubmit: { _ in })
        .frame(height: 40)
        .padding()
}
