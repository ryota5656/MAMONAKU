//
//  SettingsViewModel.swift
//  MAMONAKU
//
//  設定画面の UI 状態とサブスクリプション・カレンダー同期の制御を管理する。
//

import Foundation
import Combine
import SwiftUI
import EventKit
import UserNotifications
import UIKit

final class SettingsViewModel: ObservableObject {
    private static let calendarSyncEnabledKey = "calendar_sync_enabled"
    private static let defaultGlobalBufferMinutes = 10
    private static let minGlobalBufferMinutes = 1
    private static let maxGlobalBufferMinutes = 120

    /// サブスクリプションシートを表示するか
    @Published var showSubscriptionSheet: Bool = false

    /// 標準カレンダーと同期（App Group UserDefaults と同期。サブスク加入時のみ有効）
    @Published var calendarSyncEnabled: Bool = false {
        didSet {
            guard effectiveIsSubscribed else { return }
            userDefaults?.set(calendarSyncEnabled, forKey: Self.calendarSyncEnabledKey)
            timelineRepository.setCalendarSyncEnabled(calendarSyncEnabled)
        }
    }

    /// 次タスク通知の全体バッファ分（現状は全タスク共通）
    @Published var globalBufferMinutes: Int = 10 {
        didSet {
            let clamped = Self.clampBufferMinutes(globalBufferMinutes)
            if globalBufferMinutes != clamped {
                globalBufferMinutes = clamped
                return
            }
            guard effectiveIsSubscribed else { return }
            userDefaults?.set(clamped, forKey: AppGroup.globalBufferMinutesKey)
            bufferNotificationScheduler.reschedule(items: timelineRepository.fetchItems())
        }
    }

    /// バッファ通知のオン/オフ（加入時のみ保存）
    @Published var bufferNotificationEnabled: Bool = false {
        didSet {
            guard effectiveIsSubscribed else { return }
            userDefaults?.set(bufferNotificationEnabled, forKey: AppGroup.bufferNotificationEnabledKey)
            bufferNotificationScheduler.reschedule(items: timelineRepository.fetchItems())
        }
    }

    /// 開始時刻通知のオン/オフ
    @Published var startNotificationEnabled: Bool = true {
        didSet {
            userDefaults?.set(startNotificationEnabled, forKey: AppGroup.startNotificationEnabledKey)
            startNotificationScheduler.reschedule(items: timelineRepository.fetchItems())
        }
    }

    /// Dynamic Island / Live Activity 表示のオン/オフ（加入時のみ保存）
    @Published var liveActivityEnabled: Bool = true {
        didSet {
            guard effectiveIsSubscribed else { return }
            userDefaults?.set(liveActivityEnabled, forKey: AppGroup.liveActivityEnabledKey)
        }
    }

    /// Live Activity 複数表示のオン/オフ（加入時のみ保存）
    @Published var multipleLiveActivityEnabled: Bool = false {
        didSet {
            guard effectiveIsSubscribed else { return }
            userDefaults?.set(multipleLiveActivityEnabled, forKey: AppGroup.liveActivityMultipleEnabledKey)
        }
    }

    /// システム通知が許可されているか
    @Published var notificationPermissionEnabled: Bool = false

    /// サブスクリプション管理（View から注入）
    weak var subscriptionManager: SubscriptionManager? {
        didSet {
            guard let manager = subscriptionManager else { return }
            subscriptionObserver = manager.objectWillChange
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in
                    self?.objectWillChange.send()
                }
            loadCalendarSyncEnabled()
            loadGlobalBufferMinutes()
            loadBufferNotificationEnabled()
            loadStartNotificationEnabled()
            loadLiveActivityEnabled()
            loadMultipleLiveActivityEnabled()
            objectWillChange.send()
        }
    }

    private var userDefaults: UserDefaults? {
        UserDefaults(suiteName: AppGroup.id)
    }

    private var subscriptionObserver: AnyCancellable?
    private let eventStore = EKEventStore()
    private let timelineRepository: TimelineRepositoryProtocol = TimelineRepository()
    private let startNotificationScheduler = TimelineStartNotificationScheduler()
    private let bufferNotificationScheduler = TimelineBufferNotificationScheduler()

    init() {
        loadCalendarSyncEnabled()
        loadGlobalBufferMinutes()
        loadBufferNotificationEnabled()
        loadStartNotificationEnabled()
        loadLiveActivityEnabled()
        loadMultipleLiveActivityEnabled()
        refreshNotificationPermissionStatus()
    }

    private func loadCalendarSyncEnabled() {
        let value = userDefaults?.object(forKey: Self.calendarSyncEnabledKey) as? Bool ?? false
        if calendarSyncEnabled != value {
            calendarSyncEnabled = value
        }
    }

    private func loadGlobalBufferMinutes() {
        let raw = userDefaults?.object(forKey: AppGroup.globalBufferMinutesKey) as? Int
            ?? Self.defaultGlobalBufferMinutes
        let value = Self.clampBufferMinutes(raw)
        if globalBufferMinutes != value {
            globalBufferMinutes = value
        }
    }

    private func loadBufferNotificationEnabled() {
        let value = userDefaults?.object(forKey: AppGroup.bufferNotificationEnabledKey) as? Bool ?? false
        if bufferNotificationEnabled != value {
            bufferNotificationEnabled = value
        }
    }

    private func loadStartNotificationEnabled() {
        let value = userDefaults?.object(forKey: AppGroup.startNotificationEnabledKey) as? Bool ?? true
        if startNotificationEnabled != value {
            startNotificationEnabled = value
        }
    }

    private func loadLiveActivityEnabled() {
        let value = userDefaults?.object(forKey: AppGroup.liveActivityEnabledKey) as? Bool ?? true
        if liveActivityEnabled != value {
            liveActivityEnabled = value
        }
    }

    private func loadMultipleLiveActivityEnabled() {
        let value = userDefaults?.object(forKey: AppGroup.liveActivityMultipleEnabledKey) as? Bool ?? false
        if multipleLiveActivityEnabled != value {
            multipleLiveActivityEnabled = value
        }
    }

    private static func clampBufferMinutes(_ value: Int) -> Int {
        min(max(value, minGlobalBufferMinutes), maxGlobalBufferMinutes)
    }

    func refreshNotificationPermissionStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            let enabled: Bool
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                enabled = true
            default:
                enabled = false
            }
            DispatchQueue.main.async {
                self?.notificationPermissionEnabled = enabled
            }
        }
    }

    /// サブスクリプション加入状態（StoreKit + DEBUG オーバーライド）
    var effectiveIsSubscribed: Bool {
        if let manager = subscriptionManager {
            return manager.effectiveIsSubscribed
        }
        return userDefaults?.bool(forKey: SubscriptionManager.subscriptionStateUserDefaultsKey) ?? false
    }

    /// サブスクリプション加入状態の表示文言
    var subscriptionStatusText: String {
        effectiveIsSubscribed ? "加入中" : "未登録"
    }

    /// カレンダー同期トグルを有効にするか（加入時のみ true）
    var isCalendarSyncToggleEnabled: Bool {
        effectiveIsSubscribed
    }

    /// バッファ通知設定を有効にするか（加入時のみ true）
    var isBufferSettingEnabled: Bool {
        effectiveIsSubscribed
    }

    /// テーマ設定は常時有効（無料テーマは未加入でも選択可能）
    var isThemeSettingEnabled: Bool {
        true
    }

    /// 現在選択可能なテーマ一覧（未加入時は無料テーマのみ）
    var availableThemes: [AppPalette] {
        AppPalette.visibleInSettings
    }

    /// 現在の加入状態で選択可能なテーマか
    func canSelectTheme(_ theme: AppPalette) -> Bool {
        effectiveIsSubscribed || theme.isFreeTheme
    }

    /// Dynamic Island / Live Activity 設定を有効にするか
    var isLiveActivitySettingEnabled: Bool {
        true
    }

    /// カレンダー同期の Binding（未加入時はオフ表示・変更不可）
    var calendarSyncEnabledBinding: Binding<Bool> {
        Binding(
            get: { [self] in
                if effectiveIsSubscribed { return self.calendarSyncEnabled }
                return false
            },
            set: { [self] newValue in
                guard effectiveIsSubscribed else { return }
                if !newValue {
                    self.calendarSyncEnabled = false
                    return
                }
                requestCalendarAccessThenEnableIfGranted()
            }
        )
    }

    private func requestCalendarAccessThenEnableIfGranted() {
        let status = EKEventStore.authorizationStatus(for: .event)
        if status == .authorized || isFullAccess(status) {
            calendarSyncEnabled = true
            return
        }

        switch status {
        case .notDetermined:
            if #available(iOS 17.0, *) {
                eventStore.requestFullAccessToEvents { [weak self] granted, _ in
                    DispatchQueue.main.async {
                        self?.calendarSyncEnabled = granted
                    }
                }
            } else {
                eventStore.requestAccess(to: .event) { [weak self] granted, _ in
                    DispatchQueue.main.async {
                        self?.calendarSyncEnabled = granted
                    }
                }
            }
        default:
            calendarSyncEnabled = false
        }
    }

    private func isFullAccess(_ status: EKAuthorizationStatus) -> Bool {
        if #available(iOS 17.0, *) {
            return status == .fullAccess
        }
        return false
    }

    /// 全体バッファ分の Binding（未加入時は変更不可）
    var globalBufferMinutesBinding: Binding<Int> {
        Binding(
            get: { [self] in self.globalBufferMinutes },
            set: { [self] newValue in
                guard effectiveIsSubscribed else { return }
                self.globalBufferMinutes = Self.clampBufferMinutes(newValue)
            }
        )
    }

    /// バッファ通知オン/オフの Binding（未加入時は変更不可）
    var bufferNotificationEnabledBinding: Binding<Bool> {
        Binding(
            get: { [self] in
                if effectiveIsSubscribed { return self.bufferNotificationEnabled }
                return false
            },
            set: { [self] newValue in
                guard effectiveIsSubscribed else { return }
                self.bufferNotificationEnabled = newValue
            }
        )
    }

    /// 開始通知オン/オフの Binding
    var startNotificationEnabledBinding: Binding<Bool> {
        Binding(
            get: { [self] in self.startNotificationEnabled },
            set: { [self] newValue in
                self.startNotificationEnabled = newValue
            }
        )
    }

    /// Dynamic Island / Live Activity の Binding
    var liveActivityEnabledBinding: Binding<Bool> {
        Binding(
            get: { [self] in
                self.liveActivityEnabled
            },
            set: { [self] newValue in
                self.liveActivityEnabled = newValue
            }
        )
    }

    /// Live Activity 複数表示の Binding（未加入時は変更不可）
    var multipleLiveActivityEnabledBinding: Binding<Bool> {
        Binding(
            get: { [self] in
                if effectiveIsSubscribed { return self.multipleLiveActivityEnabled }
                return false
            },
            set: { [self] newValue in
                guard effectiveIsSubscribed else { return }
                self.multipleLiveActivityEnabled = newValue
            }
        )
    }

    /// システム通知許可の Binding（ONで許可リクエスト、OFFは設定画面へ誘導）
    var notificationPermissionBinding: Binding<Bool> {
        Binding(
            get: { [self] in self.notificationPermissionEnabled },
            set: { [self] newValue in
                if newValue {
                    requestNotificationPermission()
                } else {
                    openAppSettings()
                    refreshNotificationPermissionStatus()
                }
            }
        )
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] _, _ in
            self?.refreshNotificationPermissionStatus()
        }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        DispatchQueue.main.async {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }
        }
    }

    /// バッファ分を +5（1分のときだけ + で 5分に補正）
    func incrementBufferMinutes() {
        guard effectiveIsSubscribed else { return }
        if globalBufferMinutes < 5 {
            globalBufferMinutes = 5
            return
        }
        globalBufferMinutes = Self.clampBufferMinutes(globalBufferMinutes + 5)
    }

    /// バッファ分を -5（5分以下は 1分に補正）
    func decrementBufferMinutes() {
        guard effectiveIsSubscribed else { return }
        if globalBufferMinutes <= 5 {
            globalBufferMinutes = 1
            return
        }
        globalBufferMinutes = Self.clampBufferMinutes(globalBufferMinutes - 5)
    }

    /// サブスクリプションシートを開く
    func openSubscriptionSheet() {
        showSubscriptionSheet = true
    }

    /// サブスクリプションシートを閉じる
    func dismissSubscriptionSheet() {
        showSubscriptionSheet = false
    }

    #if DEBUG
    /// 開発用: サブスク登録オーバーライドの Binding。トグルで加入/未加入を切り替えると effectiveIsSubscribed が変わり、優先度・カレンダー同期など全 UI に反映される。
    var debugOverrideSubscribedBinding: Binding<Bool> {
        Binding(
            get: { [weak self] in
                self?.subscriptionManager?.debugOverrideSubscribed ?? false
            },
            set: { [weak self] newValue in
                self?.subscriptionManager?.debugOverrideSubscribed = newValue
            }
        )
    }
    #endif
}
