import SwiftUI

/// 設定画面のレイアウト本体。ViewState を描画し、操作を Delegate へ通知する。
struct SettingsScreenContent: View {
    @Environment(\.appTheme) private var theme

    let state: SettingsViewState
    weak var delegate: SettingsDelegate?

    var body: some View {
        List {
            SettingsAccountSection(
                subscriptionStatusText: state.subscriptionStatusText,
                onTapSubscription: { delegate?.settingsDidTapSubscription() }
            )

            SettingsCalendarSection(
                isSubscribed: state.isSubscribed,
                isCalendarSyncEnabled: state.isCalendarSyncEnabled,
                onToggleCalendarSync: { delegate?.settingsDidToggleCalendarSync($0) },
                onTapLocked: { delegate?.settingsDidTapLockedFeature() }
            )

            SettingsAppSection(state: state, delegate: delegate)

            #if DEBUG
            SettingsDebugSection(
                isSubscriptionOverridden: state.isDebugSubscriptionOverridden,
                onToggleSubscriptionOverride: { delegate?.settingsDidToggleDebugSubscription($0) }
            )
            #endif
        }
        .scrollContentBackground(.hidden)
        .background(theme.background)
        .navigationTitle("設定")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("設定")
                    .foregroundStyle(theme.textPrimary)
                    .font(.headline)
            }
        }
    }
}

// MARK: - Previews / Mock

final class PreviewSettingsDelegate: SettingsDelegate {
    /// delegate は weak で保持されるため、Preview では生成済みのインスタンスを渡す
    static let shared = PreviewSettingsDelegate()

    func settingsDidTapSubscription() {}
    func settingsDidTapLockedFeature() {}
    func settingsDidSelectTheme(_ theme: AppPalette) {}
    func settingsDidToggleCalendarSync(_ isOn: Bool) {}
    func settingsDidToggleNotificationPermission(_ isOn: Bool) {}
    func settingsDidToggleStartNotification(_ isOn: Bool) {}
    func settingsDidToggleLiveActivity(_ isOn: Bool) {}
    func settingsDidToggleLiveActivityStack(_ isOn: Bool) {}
    func settingsDidToggleBufferNotification(_ isOn: Bool) {}
    func settingsDidIncrementBufferMinutes() {}
    func settingsDidDecrementBufferMinutes() {}
    func settingsDidTapFeedback() {}
    func settingsDidTapTerms() {}
    func settingsDidTapPrivacyPolicy() {}
    func settingsDidToggleDebugSubscription(_ isOn: Bool) {}
}

#Preview("未加入") {
    NavigationStack {
        SettingsScreenContent(
            state: SettingsViewState(isNotificationPermissionGranted: true),
            delegate: PreviewSettingsDelegate.shared
        )
    }
}

#Preview("PLUS 加入中（ダーク）") {
    NavigationStack {
        SettingsScreenContent(
            state: SettingsViewState(
                isSubscribed: true,
                selectedTheme: .dark,
                isCalendarSyncEnabled: true,
                isNotificationPermissionGranted: true,
                isBufferNotificationEnabled: true
            ),
            delegate: PreviewSettingsDelegate.shared
        )
    }
    .environment(\.appTheme, .dark)
    .preferredColorScheme(.dark)
}
