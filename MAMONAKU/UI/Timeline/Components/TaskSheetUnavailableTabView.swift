import SwiftUI

/// 未実装タブ（あとで / AI）用のプレースホルダー画面
struct TaskSheetUnavailableTabView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        let secondary = AppColors.textSecondary(palette: themeManager.theme, environmentScheme: colorScheme)
        let background = AppColors.background(palette: themeManager.theme, environmentScheme: colorScheme)

        VStack {
            Spacer()
            Text("準備中")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(background)
    }
}

#Preview {
    TaskSheetUnavailableTabView()
        .environmentObject(ThemeManager())
}
