import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @EnvironmentObject private var themeManager: ThemeManager
    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        NavigationStack {
            List {
                Section("アカウント") {
                    Button {
                        viewModel.openSubscriptionSheet()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "crown.fill")
                                .font(.body)
                                .foregroundStyle(.yellow)
                                .frame(width: 28, alignment: .center)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("サブスクリプション")
                                    .foregroundStyle(.primary)
                                Text(viewModel.subscriptionStatusText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                    #if DEBUG
                    Toggle(isOn: viewModel.debugOverrideSubscribedBinding) {
                        Label("開発用: サブスク登録", systemImage: "wrench.and.screwdriver")
                    }
                    #endif
                }

                Section("カレンダー") {
                    Toggle(isOn: viewModel.calendarSyncEnabledBinding) {
                        Label("標準カレンダーと同期", systemImage: "calendar.badge.clock")
                            .foregroundStyle(.primary)
                    }
                    .disabled(!viewModel.isCalendarSyncToggleEnabled)
                }

                Section("アプリ") {
                    // テーマ設定
                    HStack {
                        Label("テーマ", systemImage: "paintpalette.fill")
                            .foregroundStyle(.primary)
                        Spacer()
                        Picker("", selection: $themeManager.theme) {
                            ForEach(AppPalette.allCases) { theme in
                                Text(theme.displayName)
                                    .tag(theme)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    SettingsRow(icon: "bell.fill", title: "通知設定", subtitle: "未設定") { }
                    SettingsRow(icon: "questionmark.circle.fill", title: "ヘルプ", subtitle: "ヘルプセンター") { }
                    SettingsRow(icon: "doc.text.fill", title: "利用規約", subtitle: "外部ページ") { }
                    SettingsRow(icon: "hand.raised.fill", title: "プライバシーポリシー", subtitle: "外部ページ") { }
                }
            }
            .navigationTitle("設定")
            .sheet(isPresented: $viewModel.showSubscriptionSheet) {
                SubscriptionSheetView()
                    .environmentObject(subscriptionManager)
            }
            .onAppear {
                viewModel.subscriptionManager = subscriptionManager
            }
        }
        .preferredColorScheme(themeManager.theme.preferredColorScheme)
    }
}

private struct SettingsRow: View {
    var icon: String = "gearshape.fill"
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(width: 28, alignment: .center)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SettingsView()
        .environmentObject(SubscriptionManager())
        .environmentObject(ThemeManager())
}
