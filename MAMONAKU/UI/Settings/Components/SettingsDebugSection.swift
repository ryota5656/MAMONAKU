#if DEBUG
import SwiftUI

/// DEBUG ビルド専用の開発者向け設定。
struct SettingsDebugSection: View {
    @Environment(\.appTheme) private var theme
    let isSubscriptionOverridden: Bool
    let onToggleSubscriptionOverride: (Bool) -> Void

    var body: some View {
        Section {
            Toggle(isOn: Binding(get: { isSubscriptionOverridden }, set: onToggleSubscriptionOverride)) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("PLUS 加入をシミュレート")
                        .foregroundStyle(theme.textPrimary)
                    Text("StoreKit の購入状態に関係なく PLUS 機能を有効化")
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                }
            }
            .tint(.orange)
        } header: {
            Text("デバッグ")
                .foregroundStyle(theme.textSecondary)
        } footer: {
            Text("リリースビルドでは表示されません。")
                .foregroundStyle(theme.textSecondary)
        }
        .listRowBackground(theme.surface)
    }
}
#endif
