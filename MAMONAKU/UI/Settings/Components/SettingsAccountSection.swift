import SwiftUI

/// 「アカウント」セクション（PLUS の加入状態）。
struct SettingsAccountSection: View {
    @Environment(\.appTheme) private var theme
    let subscriptionStatusText: String
    let onTapSubscription: () -> Void

    var body: some View {
        Section {
            SettingsLinkItem(
                icon: "crown.fill",
                iconColor: .yellow,
                title: "サブスクリプション",
                subtitle: subscriptionStatusText,
                action: onTapSubscription
            )
        } header: {
            Text("アカウント")
                .foregroundStyle(theme.textSecondary)
        }
        .listRowBackground(theme.surface)
    }
}
