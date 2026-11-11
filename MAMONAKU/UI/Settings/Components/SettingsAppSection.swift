import SwiftUI

/// 「アプリ」セクション（テーマ・通知・Live Activity・問い合わせ / 規約）。
struct SettingsAppSection: View {
    @Environment(\.appTheme) private var theme
    let state: SettingsViewState
    weak var delegate: SettingsDelegate?

    var body: some View {
        Section {
            themePicker
            notificationItems
            plusItems
            linkItems
        } header: {
            Text("アプリ")
                .foregroundStyle(theme.textSecondary)
        }
        .listRowBackground(theme.surface)
    }

    // MARK: - テーマ

    private var themePicker: some View {
        HStack {
            Label("テーマ", systemImage: "paintpalette.fill")
                .foregroundStyle(theme.textPrimary)
            Spacer()
            Picker(
                "",
                selection: Binding(
                    get: { state.selectedTheme },
                    set: { delegate?.settingsDidSelectTheme($0) }
                )
            ) {
                ForEach(state.availableThemes) { palette in
                    if state.canSelectTheme(palette) {
                        Text(palette.displayName)
                            .tag(palette)
                    } else {
                        // PLUS 限定のテーマは、王冠付きで選べない状態にして見せる
                        Label(palette.displayName, systemImage: "crown.fill")
                            .tag(palette)
                            .disabled(true)
                    }
                }
            }
            .pickerStyle(.menu)
            .tint(theme.accent)
        }
    }

    // MARK: - 通知・Live Activity（無料でも使える設定）

    @ViewBuilder
    private var notificationItems: some View {
        SettingsToggleItem(
            title: "通知を許可",
            systemImage: "bell.badge.fill",
            isOn: state.isNotificationPermissionGranted,
            onToggle: { delegate?.settingsDidToggleNotificationPermission($0) }
        )
        SettingsToggleItem(
            title: "開始通知",
            systemImage: "bell.fill",
            isOn: state.isStartNotificationEnabled,
            onToggle: { delegate?.settingsDidToggleStartNotification($0) }
        )
        SettingsToggleItem(
            title: "Live Activity表示",
            systemImage: "rectangle.topthird.inset.filled",
            isOn: state.isLiveActivityEnabled,
            onToggle: { delegate?.settingsDidToggleLiveActivity($0) }
        )
    }

    // MARK: - PLUS 限定の設定

    @ViewBuilder
    private var plusItems: some View {
        let stackTitle: LocalizedStringKey = "スタック表示（最大3件）"
        let stackImage = "rectangle.3.group.fill"
        let bufferTitle: LocalizedStringKey = "バッファ通知"
        let bufferImage = "timer"

        if state.isSubscribed {
            SettingsToggleItem(
                title: stackTitle,
                systemImage: stackImage,
                isOn: state.isLiveActivityStackEnabled,
                onToggle: { delegate?.settingsDidToggleLiveActivityStack($0) }
            )
            SettingsToggleItem(
                title: bufferTitle,
                systemImage: bufferImage,
                isOn: state.isBufferNotificationEnabled,
                onToggle: { delegate?.settingsDidToggleBufferNotification($0) }
            )
            if state.isBufferMinutesVisible {
                bufferMinutesStepper
            }
        } else {
            SettingsLockedItem(title: stackTitle, systemImage: stackImage) {
                delegate?.settingsDidTapLockedFeature()
            }
            SettingsLockedItem(title: bufferTitle, systemImage: bufferImage) {
                delegate?.settingsDidTapLockedFeature()
            }
        }
    }

    private var bufferMinutesStepper: some View {
        HStack {
            Text("通知タイミング")
                .font(.caption)
                .foregroundStyle(theme.textSecondary)
            Spacer()
            Text(state.bufferMinutesText)
                .font(.caption)
                .foregroundStyle(theme.textSecondary)
            Stepper(
                "",
                onIncrement: { delegate?.settingsDidIncrementBufferMinutes() },
                onDecrement: { delegate?.settingsDidDecrementBufferMinutes() }
            )
            .labelsHidden()
        }
    }

    // MARK: - 問い合わせ・規約

    @ViewBuilder
    private var linkItems: some View {
        SettingsLinkItem(icon: "envelope.fill", title: "要望", subtitle: "メールで送信") {
            delegate?.settingsDidTapFeedback()
        }
        SettingsLinkItem(icon: "doc.text.fill", title: "利用規約", subtitle: "外部ページ") {
            delegate?.settingsDidTapTerms()
        }
        SettingsLinkItem(icon: "hand.raised.fill", title: "プライバシーポリシー", subtitle: "外部ページ") {
            delegate?.settingsDidTapPrivacyPolicy()
        }
    }
}
