import SwiftUI

/// 画面下端に固定表示するタブバー（モーダルとは独立）。右端は Live Activity 更新ボタン。
struct TaskSheetTabBarView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @Binding var selectedTab: TaskSheetTab
    let isLiveActivityRefreshing: Bool
    let isLiveActivitySyncPending: Bool
    let onRefreshLiveActivity: () -> Void

    var body: some View {
        let secondary = AppColors.textSecondary(palette: themeManager.theme, environmentScheme: colorScheme)
        let accent = AppColors.strongAccent(palette: themeManager.theme, environmentScheme: colorScheme)
        let barBackground = AppColors.settingsListBackground(palette: themeManager.theme, environmentScheme: colorScheme)
        let primary = AppColors.primary(palette: themeManager.theme, environmentScheme: colorScheme)
        let onAccent = AppColors.onAccent(palette: themeManager.theme, environmentScheme: colorScheme)

        HStack(alignment: .bottom, spacing: 12) {
            HStack(spacing: 0) {
                ForEach(TaskSheetTab.allCases, id: \.self) { tab in
                    tabButton(tab: tab, secondary: secondary, accent: accent)
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .background(Capsule(style: .continuous).fill(barBackground))

            Button(action: onRefreshLiveActivity) {
                ZStack {
                    Circle()
                        .fill(primary)
                    if isLiveActivityRefreshing {
                        ProgressView()
                            .tint(onAccent)
                            .scaleEffect(0.85)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(onAccent)
                    }
                }
                .frame(width: 52, height: 52)
                .shadow(color: Color.primary.opacity(0.2), radius: 6, x: 0, y: 2)
                .overlay(alignment: .topTrailing) {
                    if isLiveActivitySyncPending, !isLiveActivityRefreshing {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 9, height: 9)
                            .offset(x: 2, y: -2)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(isLiveActivityRefreshing)
        }
    }

    private func tabButton(tab: TaskSheetTab, secondary: Color, accent: Color) -> some View {
        let isSelected = tab == selectedTab
        let foreground = isSelected ? accent : secondary.opacity(tab.isSelectable ? 1 : 0.45)

        return Button {
            guard tab.isSelectable else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 17, weight: .semibold))
                Text(tab.title)
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(foreground)
            .frame(minWidth: 58)
            .padding(.vertical, 2)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!tab.isSelectable)
    }
}

#Preview("TaskSheetTabBarView") {
    @Previewable @State var selectedTab: TaskSheetTab = .timeline

    TaskSheetTabBarView(
        selectedTab: $selectedTab,
        isLiveActivityRefreshing: false,
        isLiveActivitySyncPending: true,
        onRefreshLiveActivity: {}
    )
    .padding()
    .background(Color.black)
    .environmentObject(ThemeManager())
}
