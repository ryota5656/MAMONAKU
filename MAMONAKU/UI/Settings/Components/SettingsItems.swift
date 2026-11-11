import SwiftUI

/// オン/オフを切り替える設定行。
struct SettingsToggleItem: View {
    @Environment(\.appTheme) private var theme
    /// String で渡すと verbatim 表示になり、和文の約物詰めが効かなくなる
    let title: LocalizedStringKey
    let systemImage: String
    let isOn: Bool
    let onToggle: (Bool) -> Void

    var body: some View {
        Toggle(isOn: Binding(get: { isOn }, set: onToggle)) {
            Label(title, systemImage: systemImage)
                .foregroundStyle(theme.textPrimary)
        }
    }
}

/// PLUS 限定のため未加入では使えない設定行。タップで PLUS の案内を開く。
struct SettingsLockedItem: View {
    @Environment(\.appTheme) private var theme
    let title: LocalizedStringKey
    let systemImage: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Label(title, systemImage: systemImage)
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                Text("サブスク限定")
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
            }
        }
        .buttonStyle(.plain)
    }
}

/// タップで別の画面・外部ページを開く設定行（アイコン + タイトル + 補足 + シェブロン）。
struct SettingsLinkItem: View {
    @Environment(\.appTheme) private var theme
    let icon: String
    var iconColor: Color?
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(iconColor ?? theme.textPrimary)
                    .frame(width: 28, alignment: .center)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundStyle(theme.textPrimary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.textSecondary)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview("SettingsItems") {
    List {
        SettingsToggleItem(title: "開始通知", systemImage: "bell.fill", isOn: true, onToggle: { _ in })
        SettingsLockedItem(title: "バッファ通知", systemImage: "timer", onTap: {})
        SettingsLinkItem(icon: "envelope.fill", title: "要望", subtitle: "メールで送信", action: {})
    }
}
