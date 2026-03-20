//
//  SettingsViewModel.swift
//  MAMONAKU
//
//  設定画面の UI 状態とサブスクリプション・カレンダー同期の制御を管理する。
//

import Foundation
import Combine
import SwiftUI

final class SettingsViewModel: ObservableObject {
    private static let appGroupID = "group.sairyo.MAMONAKU"
    private static let calendarSyncEnabledKey = "calendar_sync_enabled"

    /// サブスクリプションシートを表示するか
    @Published var showSubscriptionSheet: Bool = false

    /// 標準カレンダーと同期（App Group UserDefaults と同期。サブスク加入時のみ有効）
    @Published var calendarSyncEnabled: Bool = true {
        didSet {
            guard effectiveIsSubscribed else { return }
            userDefaults?.set(calendarSyncEnabled, forKey: Self.calendarSyncEnabledKey)
        }
    }

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
        }
    }

    private var userDefaults: UserDefaults? {
        UserDefaults(suiteName: Self.appGroupID)
    }

    private var subscriptionObserver: AnyCancellable?

    init() {
        loadCalendarSyncEnabled()
    }

    private func loadCalendarSyncEnabled() {
        let value = userDefaults?.object(forKey: Self.calendarSyncEnabledKey) as? Bool ?? true
        if calendarSyncEnabled != value {
            calendarSyncEnabled = value
        }
    }

    /// サブスクリプション加入状態（StoreKit + DEBUG オーバーライド）
    var effectiveIsSubscribed: Bool {
        subscriptionManager?.effectiveIsSubscribed ?? false
    }

    /// サブスクリプション加入状態の表示文言
    var subscriptionStatusText: String {
        effectiveIsSubscribed ? "加入中" : "未登録"
    }

    /// カレンダー同期トグルを有効にするか（加入時のみ true）
    var isCalendarSyncToggleEnabled: Bool {
        effectiveIsSubscribed
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
                self.calendarSyncEnabled = newValue
            }
        )
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
