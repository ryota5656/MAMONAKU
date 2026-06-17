import SwiftUI

struct SettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @EnvironmentObject private var themeManager: ThemeManager
    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        let state = viewModel.state
        let primary = AppColors.textPrimary(palette: themeManager.theme, environmentScheme: colorScheme)
        let secondary = AppColors.textSecondary(palette: themeManager.theme, environmentScheme: colorScheme)
        let accent = AppColors.accent(palette: themeManager.theme, environmentScheme: colorScheme)
        let background = AppColors.background(palette: themeManager.theme, environmentScheme: colorScheme)
        let listBackground = AppColors.settingsListBackground(palette: themeManager.theme, environmentScheme: colorScheme)

        NavigationStack {
            List {
                AccountSectionView(
                    primary: primary,
                    secondary: secondary,
                    listBackground: listBackground,
                    subscriptionStatusText: state.subscriptionStatusText,
                    onTapSubscription: { viewModel.openSubscriptionSheet() }
                )

                CalendarSectionView(
                    primary: primary,
                    secondary: secondary,
                    listBackground: listBackground,
                    isCalendarSyncToggleEnabled: state.isCalendarSyncToggleEnabled,
                    calendarSyncEnabled: viewModel.calendarSyncEnabledBinding,
                    onTapLocked: { viewModel.openSubscriptionSheet() }
                )

                AppSectionView(
                    primary: primary,
                    secondary: secondary,
                    accent: accent,
                    listBackground: listBackground,
                    theme: themeManager.theme,
                    availableThemes: state.availableThemes,
                    canSelectTheme: viewModel.canSelectTheme,
                    onSelectTheme: { theme in
                        viewModel.selectTheme(theme) { themeManager.theme = $0 }
                    },
                    notificationPermission: viewModel.notificationPermissionBinding,
                    startNotificationEnabled: viewModel.startNotificationEnabledBinding,
                    liveActivityEnabled: viewModel.liveActivityEnabledBinding,
                    isBufferSettingEnabled: state.isBufferSettingEnabled,
                    multipleLiveActivityEnabled: viewModel.multipleLiveActivityEnabledBinding,
                    bufferNotificationEnabled: viewModel.bufferNotificationEnabledBinding,
                    isBufferMinutesVisible: state.isBufferMinutesVisible,
                    bufferMinutesText: "\(state.globalBufferMinutes)分前",
                    onIncrementBufferMinutes: { viewModel.incrementBufferMinutes() },
                    onDecrementBufferMinutes: { viewModel.decrementBufferMinutes() },
                    onTapLocked: { viewModel.openSubscriptionSheet() },
                    onTapFeedback: { viewModel.openMailFeedback() },
                    onTapTerms: { viewModel.openTerms() },
                    onTapPrivacy: { viewModel.openPrivacyPolicy() }
                )
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
            .sheet(isPresented: Binding(get: { viewModel.state.showSubscriptionSheet }, set: { viewModel.showSubscriptionSheet = $0 })) {
                SubscriptionSheetView()
                    .environmentObject(subscriptionManager)
                    .environmentObject(themeManager)
            }
            .onChange(of: viewModel.route) { _, route in
                guard let route else { return }
                switch route {
                case .openURL(let url):
                    openURL(url)
                }
                viewModel.handleRouteConsumed()
            }
            .onAppear {
                viewModel.subscriptionManager = subscriptionManager
                viewModel.refreshNotificationPermissionStatus()
            }
        }
        .background(background)
        .preferredColorScheme(themeManager.theme.preferredColorScheme)
    }
}

#Preview {
    SettingsView()
        .environmentObject(SubscriptionManager())
        .environmentObject(ThemeManager())
}
