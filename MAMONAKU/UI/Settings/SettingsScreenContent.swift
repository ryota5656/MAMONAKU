import SwiftUI

/// 設定画面のレイアウト本体。ViewState と Delegate を受け取り UI 描画に専念する。
struct SettingsScreenContent: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    let state: SettingsViewState
    @ObservedObject var viewModel: SettingsViewModel
    let delegate: SettingsDelegate?

    var body: some View {
        let primary = AppColors.textPrimary(palette: themeManager.theme, environmentScheme: colorScheme)
        let secondary = AppColors.textSecondary(palette: themeManager.theme, environmentScheme: colorScheme)
        let accent = AppColors.accent(palette: themeManager.theme, environmentScheme: colorScheme)
        let background = AppColors.background(palette: themeManager.theme, environmentScheme: colorScheme)
        let listBackground = AppColors.settingsListBackground(palette: themeManager.theme, environmentScheme: colorScheme)

        List {
            AccountSectionView(
                primary: primary,
                secondary: secondary,
                listBackground: listBackground,
                subscriptionStatusText: state.subscriptionStatusText,
                onTapSubscription: {
                    delegate?.settingsOpenSubscriptionSheet()
                }
            )

            CalendarSectionView(
                primary: primary,
                secondary: secondary,
                listBackground: listBackground,
                isCalendarSyncToggleEnabled: state.isCalendarSyncToggleEnabled,
                calendarSyncEnabled: viewModel.calendarSyncEnabledBinding,
                onTapLocked: {
                    delegate?.settingsOpenSubscriptionSheet()
                }
            )

            AppSectionView(
                primary: primary,
                secondary: secondary,
                accent: accent,
                listBackground: listBackground,
                theme: themeManager.theme,
                availableThemes: state.availableThemes,
                canSelectTheme: { delegate?.settingsCanSelectTheme($0) ?? false },
                onSelectTheme: { theme in
                    delegate?.settingsSelectTheme(theme)
                },
                notificationPermission: viewModel.notificationPermissionBinding,
                startNotificationEnabled: viewModel.startNotificationEnabledBinding,
                liveActivityEnabled: viewModel.liveActivityEnabledBinding,
                isBufferSettingEnabled: state.isBufferSettingEnabled,
                multipleLiveActivityEnabled: viewModel.multipleLiveActivityEnabledBinding,
                bufferNotificationEnabled: viewModel.bufferNotificationEnabledBinding,
                isBufferMinutesVisible: state.isBufferMinutesVisible,
                bufferMinutesText: "\(state.globalBufferMinutes)分前",
                onIncrementBufferMinutes: {
                    delegate?.settingsIncrementBufferMinutes()
                },
                onDecrementBufferMinutes: {
                    delegate?.settingsDecrementBufferMinutes()
                },
                onTapLocked: {
                    delegate?.settingsOpenSubscriptionSheet()
                },
                onTapFeedback: {
                    delegate?.settingsOpenMailFeedback()
                },
                onTapTerms: {
                    delegate?.settingsOpenTerms()
                },
                onTapPrivacy: {
                    delegate?.settingsOpenPrivacyPolicy()
                }
            )

            #if DEBUG
            DebugSettingsSectionView(
                primary: primary,
                secondary: secondary,
                listBackground: listBackground,
                debugOverrideSubscribed: viewModel.debugOverrideSubscribedBinding
            )
            #endif
        }
        .scrollContentBackground(.hidden)
        .background(background)
        .navigationTitle("設定")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("設定")
                    .foregroundStyle(primary)
                    .font(.headline)
            }
        }
    }
}

// MARK: - Previews / Mock

final class PreviewSettingsDelegate: SettingsDelegate {
    func settingsDidAppear(subscriptionManager: SubscriptionManager) {}
    func settingsOpenSubscriptionSheet() {}
    func settingsSelectTheme(_ theme: AppPalette) {}
    func settingsCanSelectTheme(_ theme: AppPalette) -> Bool { theme.isFreeTheme }
    func settingsIncrementBufferMinutes() {}
    func settingsDecrementBufferMinutes() {}
    func settingsOpenMailFeedback() {}
    func settingsOpenTerms() {}
    func settingsOpenPrivacyPolicy() {}
}

#Preview("設定画面") {
    NavigationStack {
        SettingsScreenContent(
            state: SettingsViewState(
                showSubscriptionSheet: false,
                subscriptionStatusText: "未登録",
                effectiveIsSubscribed: false,
                isCalendarSyncToggleEnabled: false,
                calendarSyncEnabled: false,
                isThemeSettingEnabled: true,
                availableThemes: AppPalette.visibleInSettings,
                notificationPermissionEnabled: true,
                startNotificationEnabled: true,
                liveActivityEnabled: true,
                multipleLiveActivityEnabled: false,
                bufferNotificationEnabled: false,
                globalBufferMinutes: 10,
                isBufferSettingEnabled: false,
                isBufferMinutesVisible: false
            ),
            viewModel: SettingsViewModel(timelineRepository: PreviewTimelineRepository()),
            delegate: PreviewSettingsDelegate()
        )
    }
    .environmentObject(ThemeManager())
}

private final class PreviewTimelineRepository: TimelineRepositoryProtocol {
    func fetchItems() -> [TimelineItem] { [] }
    func saveItems(_ items: [TimelineItem]) {}
    func addItem(_ item: TimelineItem) {}
    func updateItem(_ item: TimelineItem) {}
    func deleteItem(id: UUID) {}
    func fetchNextItemSummary(referenceDate: Date) -> TimelineNextItemSummary? { nil }
    func deleteItemAndEvent(id: UUID) {}
    func setCalendarSyncEnabled(_ enabled: Bool) {}
}
