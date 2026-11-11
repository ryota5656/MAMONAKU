import SwiftUI

/// 設定画面のエントリーポイント。ViewModel の保持と、シート・外部 URL などのシステム制御を担う。
///
/// 加入状態と選択中テーマはアプリ全体で共有する `SubscriptionManager` / `ThemeManager` が持つため、
/// ここで値の変化を ViewModel へ伝え、ViewModel からの変更指示（`Route`）を反映する。
struct SettingsScreen: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var viewModel: SettingsViewModel

    init(viewModel: SettingsViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            SettingsScreenContent(state: viewModel.state, delegate: viewModel)
                .sheet(isPresented: subscriptionSheetPresented) {
                    SubscriptionSheetView()
                }
                .onChange(of: viewModel.route) { _, route in
                    guard let route else { return }
                    perform(route)
                    viewModel.handleRouteConsumed()
                }
                .onAppear {
                    syncEnvironment()
                    Task { await viewModel.onAppear() }
                }
                .onChange(of: subscriptionManager.effectiveIsSubscribed) { _, _ in
                    syncEnvironment()
                }
                .onChange(of: themeManager.theme) { _, _ in
                    syncEnvironment()
                }
        }
        .background(theme.background)
        .preferredColorScheme(themeManager.theme.preferredColorScheme)
    }

    private var subscriptionSheetPresented: Binding<Bool> {
        Binding(
            get: { viewModel.state.isSubscriptionSheetPresented },
            set: { isPresented in
                if !isPresented { viewModel.dismissSubscriptionSheet() }
            }
        )
    }

    /// 加入状態・選択中テーマを ViewModel へ伝える。
    private func syncEnvironment() {
        viewModel.environmentDidChange(
            isSubscribed: subscriptionManager.effectiveIsSubscribed,
            selectedTheme: themeManager.theme,
            isDebugSubscriptionOverridden: isDebugSubscriptionOverridden
        )
    }

    private var isDebugSubscriptionOverridden: Bool {
        #if DEBUG
        subscriptionManager.debugOverrideSubscribed
        #else
        false
        #endif
    }

    private func perform(_ route: SettingsViewModel.Route) {
        switch route {
        case .openURL(let url):
            openURL(url)
        case .openSystemSettings:
            if let url = URL(string: UIApplication.openSettingsURLString) {
                openURL(url)
            }
        case .applyTheme(let palette):
            themeManager.theme = palette
        case .setDebugSubscriptionOverride(let isOn):
            #if DEBUG
            subscriptionManager.debugOverrideSubscribed = isOn
            syncEnvironment()
            #endif
        }
    }
}
