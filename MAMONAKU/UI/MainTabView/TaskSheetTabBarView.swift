import SwiftUI

/// 画面下端に固定表示するタブバー（モーダルとは独立）。
/// 右端は通常 Live Activity 更新、タイムライン編集中は完了ボタン。
struct TaskSheetTabBarView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    @Binding var selectedTab: TaskSheetTab
    let isTimelineEditing: Bool
    let isLiveActivityRefreshing: Bool
    let isLiveActivitySyncPending: Bool
    let onCompleteEditing: () -> Void
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

            if isTimelineEditing {
                completeEditingButton(primary: primary, onAccent: onAccent)
            } else {
                refreshLiveActivityButton(primary: primary, onAccent: onAccent)
            }
        }
    }

    private func completeEditingButton(primary: Color, onAccent: Color) -> some View {
        Button(action: onCompleteEditing) {
            ZStack {
                Circle()
                    .fill(primary)
                Image(systemName: "checkmark")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(onAccent)
            }
            .frame(width: 52, height: 52)
            .shadow(color: Color.primary.opacity(0.2), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("編集を完了")
    }

    private func refreshLiveActivityButton(primary: Color, onAccent: Color) -> some View {
        let canRefresh = isLiveActivitySyncPending && !isLiveActivityRefreshing

        return Button(action: onRefreshLiveActivity) {
            ZStack {
                Circle()
                    .fill(primary.opacity(canRefresh ? 1 : 0.35))
                if isLiveActivityRefreshing {
                    ProgressView()
                        .tint(onAccent)
                        .scaleEffect(0.85)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(onAccent.opacity(canRefresh ? 1 : 0.55))
                }
            }
            .frame(width: 52, height: 52)
            .shadow(color: Color.primary.opacity(canRefresh ? 0.2 : 0.08), radius: 6, x: 0, y: 2)
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
        .disabled(!canRefresh)
        .accessibilityLabel("ロック画面を更新")
        .accessibilityHint(canRefresh ? "未反映の予定をロック画面に送ります" : "反映待ちの変更はありません")
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

    VStack(spacing: 24) {
        TaskSheetTabBarView(
            selectedTab: $selectedTab,
            isTimelineEditing: false,
            isLiveActivityRefreshing: false,
            isLiveActivitySyncPending: true,
            onCompleteEditing: {},
            onRefreshLiveActivity: {}
        )

        TaskSheetTabBarView(
            selectedTab: $selectedTab,
            isTimelineEditing: true,
            isLiveActivityRefreshing: false,
            isLiveActivitySyncPending: false,
            onCompleteEditing: {},
            onRefreshLiveActivity: {}
        )
    }
    .padding()
    .background(Color.black)
    .environmentObject(ThemeManager())
}
