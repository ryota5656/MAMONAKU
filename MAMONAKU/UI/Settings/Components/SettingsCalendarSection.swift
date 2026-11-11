import SwiftUI

/// 「カレンダー」セクション（標準カレンダーとの同期。PLUS 限定）。
struct SettingsCalendarSection: View {
    @Environment(\.appTheme) private var theme
    let isSubscribed: Bool
    let isCalendarSyncEnabled: Bool
    let onToggleCalendarSync: (Bool) -> Void
    let onTapLocked: () -> Void

    var body: some View {
        Section {
            if isSubscribed {
                SettingsToggleItem(
                    title: "標準カレンダーと同期",
                    systemImage: "calendar.badge.clock",
                    isOn: isCalendarSyncEnabled,
                    onToggle: onToggleCalendarSync
                )
            } else {
                SettingsLockedItem(
                    title: "標準カレンダーと同期",
                    systemImage: "calendar.badge.clock",
                    onTap: onTapLocked
                )
            }
        } header: {
            Text("カレンダー")
                .foregroundStyle(theme.textSecondary)
        }
        .listRowBackground(theme.surface)
    }
}
