import SwiftUI

struct AppSectionView: View {
    let primary: Color
    let secondary: Color
    let accent: Color
    let listBackground: Color

    let theme: AppPalette
    let availableThemes: [AppPalette]
    let canSelectTheme: (AppPalette) -> Bool
    let onSelectTheme: (AppPalette) -> Void

    let notificationPermission: Binding<Bool>
    let startNotificationEnabled: Binding<Bool>
    let liveActivityEnabled: Binding<Bool>

    let isBufferSettingEnabled: Bool
    let multipleLiveActivityEnabled: Binding<Bool>
    let bufferNotificationEnabled: Binding<Bool>
    let isBufferMinutesVisible: Bool
    let bufferMinutesText: String
    let onIncrementBufferMinutes: () -> Void
    let onDecrementBufferMinutes: () -> Void

    let onTapLocked: () -> Void
    let onTapFeedback: () -> Void
    let onTapTerms: () -> Void
    let onTapPrivacy: () -> Void

    var body: some View {
        Section {
            HStack {
                Label("テーマ", systemImage: "paintpalette.fill")
                    .foregroundStyle(primary)
                Spacer()
                Picker(
                    "",
                    selection: Binding(get: { theme }, set: { onSelectTheme($0) })
                ) {
                    ForEach(availableThemes) { theme in
                        if canSelectTheme(theme) {
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

            Toggle(isOn: notificationPermission) {
                Label("通知を許可", systemImage: "bell.badge.fill")
                    .foregroundStyle(primary)
            }

            Toggle(isOn: startNotificationEnabled) {
                Label("開始通知", systemImage: "bell.fill")
                    .foregroundStyle(primary)
            }

            Toggle(isOn: liveActivityEnabled) {
                Label("Live Activity表示", systemImage: "rectangle.topthird.inset.filled")
                    .foregroundStyle(primary)
            }

            if isBufferSettingEnabled {
                Toggle(isOn: multipleLiveActivityEnabled) {
                    Label("複数Live Activity表示", systemImage: "rectangle.3.group.fill")
                        .foregroundStyle(primary)
                }

                Toggle(isOn: bufferNotificationEnabled) {
                    Label("バッファ通知", systemImage: "timer")
                        .foregroundStyle(primary)
                }

                if isBufferMinutesVisible {
                    HStack {
                        Text("通知タイミング")
                            .font(.caption)
                            .foregroundStyle(secondary)
                        Spacer()
                        Text(bufferMinutesText)
                            .font(.caption)
                            .foregroundStyle(secondary)
                        Stepper("", onIncrement: onIncrementBufferMinutes, onDecrement: onDecrementBufferMinutes)
                            .labelsHidden()
                    }
                }
            } else {
                Button(action: onTapLocked) {
                    HStack(spacing: 12) {
                        Label("複数Live Activity表示", systemImage: "rectangle.3.group.fill")
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

                Button(action: onTapLocked) {
                    HStack(spacing: 12) {
                        Label("バッファ通知", systemImage: "timer")
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

            SettingsRow(icon: "envelope.fill", title: "要望", subtitle: "メールで送信", action: onTapFeedback)
            SettingsRow(icon: "doc.text.fill", title: "利用規約", subtitle: "外部ページ", action: onTapTerms)
            SettingsRow(icon: "hand.raised.fill", title: "プライバシーポリシー", subtitle: "外部ページ", action: onTapPrivacy)
        } header: {
            Text("アプリ")
                .foregroundStyle(secondary)
        }
        .listRowBackground(listBackground)
    }
}

