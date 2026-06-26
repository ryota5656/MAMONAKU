import SwiftUI

/// 設定画面のエントリーポイント。ViewModel の保持とシステム制御（Sheet / 外部 URL）のみを担う。
struct SettingsScreen: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @EnvironmentObject private var themeManager: ThemeManager
    @StateObject private var viewModel: SettingsViewModel

    init() {
        _viewModel = StateObject(wrappedValue: SettingsViewModel())
    }

    init(viewModel: SettingsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        let background = AppColors.background(
            palette: themeManager.theme,
            environmentScheme: colorScheme
        )

        NavigationStack {
            SettingsScreenContent(
                state: viewModel.state,
                viewModel: viewModel,
                delegate: viewModel
            )
            .sheet(isPresented: subscriptionSheetPresented) {
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
                viewModel.onApplyTheme = { themeManager.theme = $0 }
                viewModel.settingsDidAppear(subscriptionManager: subscriptionManager)
            }
        }
        .background(background)
        .preferredColorScheme(themeManager.theme.preferredColorScheme)
    }

    private var subscriptionSheetPresented: Binding<Bool> {
        Binding(
            get: { viewModel.showSubscriptionSheet },
            set: { viewModel.showSubscriptionSheet = $0 }
        )
    }
}

#Preview {
    SettingsScreen()
        .environmentObject(SubscriptionManager())
        .environmentObject(ThemeManager())
}
