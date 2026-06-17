import SwiftUI

struct PendingPlacementCardView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var title: String = ""
    @FocusState private var isFocused: Bool
    var onSubmit: (String) -> Void
    var onCancel: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            TextField("タイトルを入力", text: $title)
                .textFieldStyle(.plain)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppColors.textPrimary(palette: themeManager.theme, environmentScheme: colorScheme))
                .padding(.horizontal, 20)
                .padding(.vertical, 6)
                .submitLabel(.done)
                .onSubmit {
                    onSubmit(title)
                }
                .focused($isFocused)
                .onAppear { isFocused = true }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppColors.settingsListBackground(palette: themeManager.theme, environmentScheme: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppColors.gridLine(palette: themeManager.theme, environmentScheme: colorScheme), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
        )
    }
}

