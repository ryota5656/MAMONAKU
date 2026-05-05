import SwiftUI

struct SettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @EnvironmentObject private var themeManager: ThemeManager
    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        let primary = AppColors.textPrimary(palette: themeManager.theme, environmentScheme: colorScheme)
        let secondary = AppColors.textSecondary(palette: themeManager.theme, environmentScheme: colorScheme)
        let accent = AppColors.accent(palette: themeManager.theme, environmentScheme: colorScheme)
        let background = AppColors.background(palette: themeManager.theme, environmentScheme: colorScheme)
        let listBackground = AppColors.settingsListBackground(palette: themeManager.theme, environmentScheme: colorScheme)

        NavigationStack {
            List {
                Section {
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
                                    .foregroundStyle(AppColors.textPrimary(palette: themeManager.theme, environmentScheme: colorScheme))
                                Text(viewModel.subscriptionStatusText)
                                    .font(.caption)
                                    .foregroundStyle(AppColors.textSecondary(palette: themeManager.theme, environmentScheme: colorScheme))
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    #if DEBUG
                    Toggle(isOn: viewModel.debugOverrideSubscribedBinding) {
                        Label("開発用: サブスク登録", systemImage: "wrench.and.screwdriver")
                    }
                    #endif
                } header: {
                    Text("アカウント")
                        .foregroundStyle(secondary)
                }
                .listRowBackground(listBackground)

                Section {
                    if viewModel.isCalendarSyncToggleEnabled {
                        Toggle(isOn: viewModel.calendarSyncEnabledBinding) {
                            Label("標準カレンダーと同期", systemImage: "calendar.badge.clock")
                                .foregroundStyle(primary)
                        }
                    } else {
                        Button {
                            viewModel.openSubscriptionSheet()
                        } label: {
                            HStack(spacing: 12) {
                                Label("標準カレンダーと同期", systemImage: "calendar.badge.clock")
                                    .foregroundStyle(primary)
                                Spacer()
                                Text("サブスク限定")
                                    .font(.caption)
                                    .foregroundStyle(secondary)
                                Image(systemName: "lock.fill")
                                    .font(.caption)
                                    .foregroundStyle(secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("カレンダー")
                        .foregroundStyle(secondary)
                }
                .listRowBackground(listBackground)

                Section {
                    // テーマ設定
                    if viewModel.isThemeSettingEnabled {
                        HStack {
                            Label("テーマ", systemImage: "paintpalette.fill")
                                .foregroundStyle(primary)
                            Spacer()
                            Picker(
                                "",
                                selection: Binding(
                                    get: { themeManager.theme },
                                    set: { newTheme in
                                        if viewModel.canSelectTheme(newTheme) {
                                            themeManager.theme = newTheme
                                        } else {
                                            viewModel.openSubscriptionSheet()
                                        }
                                    }
                                )
                            ) {
                                ForEach(viewModel.availableThemes) { theme in
                                    if viewModel.canSelectTheme(theme) {
                                        Text(theme.displayName)
                                            .tag(theme)
                                    } else {
                                        Label(theme.displayName, systemImage: "crown.fill")
                                            .tag(theme)
                                            .disabled(true)
                                    }
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(accent)
                        }
                    } else {
                        Button {
                            viewModel.openSubscriptionSheet()
                        } label: {
                            HStack(spacing: 12) {
                                Label("テーマ", systemImage: "paintpalette.fill")
                                    .foregroundStyle(primary)
                                Spacer()
                                Text("サブスク限定")
                                    .font(.caption)
                                    .foregroundStyle(secondary)
                                Image(systemName: "lock.fill")
                                    .font(.caption)
                                    .foregroundStyle(secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    Toggle(isOn: viewModel.notificationPermissionBinding) {
                        Label("通知を許可", systemImage: "bell.badge.fill")
                            .foregroundStyle(AppColors.textPrimary(palette: themeManager.theme, environmentScheme: colorScheme))
                    }

                    Toggle(isOn: viewModel.startNotificationEnabledBinding) {
                        Label("開始通知", systemImage: "bell.fill")
                            .foregroundStyle(AppColors.textPrimary(palette: themeManager.theme, environmentScheme: colorScheme))
                    }

                    Toggle(isOn: viewModel.liveActivityEnabledBinding) {
                        Label("Live Activity表示", systemImage: "rectangle.topthird.inset.filled")
                            .foregroundStyle(AppColors.textPrimary(palette: themeManager.theme, environmentScheme: colorScheme))
                    }

                    if viewModel.isBufferSettingEnabled {
                        Toggle(isOn: viewModel.multipleLiveActivityEnabledBinding) {
                            Label("複数Live Activity表示", systemImage: "rectangle.3.group.fill")
                                .foregroundStyle(AppColors.textPrimary(palette: themeManager.theme, environmentScheme: colorScheme))
                        }

                        Toggle(isOn: viewModel.bufferNotificationEnabledBinding) {
                            Label("バッファ通知", systemImage: "timer")
                                .foregroundStyle(AppColors.textPrimary(palette: themeManager.theme, environmentScheme: colorScheme))
                        }

                        if viewModel.bufferNotificationEnabled {
                            HStack {
                                Text("通知タイミング")
                                    .font(.caption)
                                    .foregroundStyle(secondary)
                                Spacer()
                                Text("\(viewModel.globalBufferMinutes)分前")
                                    .font(.caption)
                                    .foregroundStyle(AppColors.textSecondary(palette: themeManager.theme, environmentScheme: colorScheme))
                                Stepper(
                                    "",
                                    onIncrement: { viewModel.incrementBufferMinutes() },
                                    onDecrement: { viewModel.decrementBufferMinutes() }
                                )
                                .labelsHidden()
                            }
                        }
                    } else {
                        Button {
                            viewModel.openSubscriptionSheet()
                        } label: {
                            HStack(spacing: 12) {
                                Label("複数Live Activity表示", systemImage: "rectangle.3.group.fill")
                                    .foregroundStyle(AppColors.textPrimary(palette: themeManager.theme, environmentScheme: colorScheme))
                                Spacer()
                                Text("サブスク限定")
                                    .font(.caption)
                                    .foregroundStyle(AppColors.textSecondary(palette: themeManager.theme, environmentScheme: colorScheme))
                                Image(systemName: "lock.fill")
                                    .font(.caption)
                                    .foregroundStyle(AppColors.textSecondary(palette: themeManager.theme, environmentScheme: colorScheme))
                            }
                        }
                        .buttonStyle(.plain)

                        Button {
                            viewModel.openSubscriptionSheet()
                        } label: {
                            HStack(spacing: 12) {
                                Label("バッファ通知", systemImage: "timer")
                                    .foregroundStyle(AppColors.textPrimary(palette: themeManager.theme, environmentScheme: colorScheme))
                                Spacer()
                                Text("サブスク限定")
                                    .font(.caption)
                                    .foregroundStyle(AppColors.textSecondary(palette: themeManager.theme, environmentScheme: colorScheme))
                                Image(systemName: "lock.fill")
                                    .font(.caption)
                                    .foregroundStyle(AppColors.textSecondary(palette: themeManager.theme, environmentScheme: colorScheme))
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    SettingsRow(icon: "envelope.fill", title: "要望", subtitle: "メールで送信") {
                        guard let url = URL(string: "mailto:kopernix5656@icloud.com") else { return }
                        openURL(url)
                    }
                    SettingsRow(icon: "doc.text.fill", title: "利用規約", subtitle: "外部ページ") {
                        guard let url = URL(string: "https://note.com/quirky_magpie934/n/n7746f82a9f27") else { return }
                        openURL(url)
                    }
                    SettingsRow(icon: "hand.raised.fill", title: "プライバシーポリシー", subtitle: "外部ページ") {
                        guard let url = URL(string: "https://note.com/quirky_magpie934/n/naec276dc2d9b") else { return }
                        openURL(url)
                    }
                } header: {
                    Text("アプリ")
                        .foregroundStyle(secondary)
                }
                .listRowBackground(listBackground)
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
            .sheet(isPresented: $viewModel.showSubscriptionSheet) {
                SubscriptionSheetView()
                    .environmentObject(subscriptionManager)
                    .environmentObject(themeManager)
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

private struct SettingsRow: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager
    var icon: String = "gearshape.fill"
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(AppColors.textPrimary(palette: themeManager.theme, environmentScheme: colorScheme))
                    .frame(width: 28, alignment: .center)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundStyle(AppColors.textPrimary(palette: themeManager.theme, environmentScheme: colorScheme))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary(palette: themeManager.theme, environmentScheme: colorScheme))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.textSecondary(palette: themeManager.theme, environmentScheme: colorScheme))
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
