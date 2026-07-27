//
//  SubscriptionManager.swift
//  MAMONAKU
//
//  PLUS 利用権の状態。StoreKit 2 のサブスクリプション / 買い切り製品と紐づけ。
//  未加入時は優先度を Low のみに制限する。
//

import Foundation
import Combine
import StoreKit

final class SubscriptionManager: ObservableObject {
    /// PLUS 製品 ID（App Store Connect で作成した ID）
    static let subscriptionMonthlyProductID = "mamonaku.subscription.plus.monthly"
    static let subscriptionYearlyProductID = "mamonaku.subscription.plus.yearly"
    static let subscriptionLegacyProductID = "mamonaku.subscription.plus"
    static let plusLifetimeProductID = "mamonaku.inAppPurchase.plus"
    static let subscriptionProductIDs = [
        plusLifetimeProductID,
        subscriptionYearlyProductID,
        subscriptionMonthlyProductID,
        subscriptionLegacyProductID
    ]
    /// App Group の UserDefaults に書き出すキー（TimelineRepository のカレンダー同期判定で参照）
    static let subscriptionStateUserDefaultsKey = AppGroup.subscriptionIsSubscribedKey
    private static let appGroupID = AppGroup.id

    /// 加入中は true。未加入は優先度を Low のみで登録可能。StoreKit の currentEntitlements で更新。
    @Published private(set) var isSubscribed: Bool = false {
        didSet { persistSubscriptionState() }
    }

    /// UI で参照する加入状態。本番は isSubscribed と同一。DEBUG 時は開発用オーバーライドを加味。
    var effectiveIsSubscribed: Bool {
        #if DEBUG
        return isSubscribed || debugOverrideSubscribed
        #else
        return isSubscribed
        #endif
    }

    #if DEBUG
    /// 開発用: true の間は加入扱い（StoreKit 未購入でも優先度選択可能）。トグルで変更すると objectWillChange と UserDefaults 同期で他 UI に反映される。
    var debugOverrideSubscribed: Bool = true {
        didSet {
            objectWillChange.send()
            persistSubscriptionState()
        }
    }
    #endif

    /// 読み込み済みのサブスクリプション製品（購入 UI 用）
    @Published private(set) var subscriptionProducts: [Product] = []
    var subscriptionProduct: Product? { subscriptionProducts.first }

    /// 購入処理中
    @Published private(set) var isPurchasing: Bool = false

    /// エラーメッセージ（購入失敗時など）
    @Published var errorMessage: String?

    private var updateTask: Task<Void, Never>?
    private var listenerTask: Task<Void, Never>?

    init() {
        persistSubscriptionState()
        updateTask = Task { @MainActor in
            await loadProducts()
            await updateSubscriptionStatus()
        }
        listenerTask = Task { @MainActor in
            await listenTransactionUpdates()
        }
    }

    deinit {
        updateTask?.cancel()
        listenerTask?.cancel()
    }

    /// 製品一覧を読み込み
    @MainActor
    func loadProducts() async {
        do {
            let products = try await Product.products(for: Self.subscriptionProductIDs)
            subscriptionProducts = products.sorted { lhs, rhs in
                Self.preferredSortOrder(for: lhs.id) < Self.preferredSortOrder(for: rhs.id)
            }
        } catch {
            errorMessage = "製品の読み込みに失敗しました"
        }
    }

    /// Transaction.currentEntitlements から加入状態を更新
    @MainActor
    func updateSubscriptionStatus() async {
        let now = Date()
        var hasEntitlement = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  Self.subscriptionProductIDs.contains(transaction.productID),
                  transaction.revocationDate == nil
            else { continue }

            if let expirationDate = transaction.expirationDate {
                guard expirationDate > now else { continue }
            }

            if transaction.isUpgraded {
                continue
            }

            if Self.subscriptionProductIDs.contains(transaction.productID) {
                hasEntitlement = true
                break
            }
        }
        if isSubscribed != hasEntitlement {
            isSubscribed = hasEntitlement
        }
    }

    /// 加入状態を App Group UserDefaults に書き出し（Repository のカレンダー同期判定で参照）
    private func persistSubscriptionState() {
        UserDefaults(suiteName: Self.appGroupID)?
            .set(effectiveIsSubscribed, forKey: Self.subscriptionStateUserDefaultsKey)
    }
    
    /// トランザクション更新の監視（購入・更新・失効など）
    private func listenTransactionUpdates() async {
        for await result in Transaction.updates {
            await MainActor.run {
                guard case .verified(let transaction) = result else { return }
                if Self.subscriptionProductIDs.contains(transaction.productID) {
                    Task { @MainActor in
                        await updateSubscriptionStatus()
                    }
                }
            }
        }
    }

    private static func preferredSortOrder(for id: String) -> Int {
        if id == plusLifetimeProductID { return 0 }
        if id == subscriptionYearlyProductID { return 1 }
        if id == subscriptionMonthlyProductID { return 2 }
        if id == subscriptionLegacyProductID { return 3 }
        return 9
    }

    /// サブスクリプションを購入
    @MainActor
    func purchase() async {
        guard let product = subscriptionProduct else {
            errorMessage = "製品を読み込み直してください"
            await loadProducts()
            return
        }
        await purchase(product: product)
    }

    /// 指定したサブスクリプション製品を購入
    @MainActor
    func purchase(product: Product) async {
        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    await updateSubscriptionStatus()
                    AnalyticsService.log(
                        AnalyticsService.Event.subscriptionPurchase,
                        parameters: [
                            AnalyticsService.Param.productId: product.id,
                            AnalyticsService.Param.success: 1
                        ]
                    )
                case .unverified:
                    errorMessage = "検証に失敗しました"
                    AnalyticsService.log(
                        AnalyticsService.Event.subscriptionPurchase,
                        parameters: [
                            AnalyticsService.Param.productId: product.id,
                            AnalyticsService.Param.success: 0
                        ]
                    )
                }
            case .userCancelled:
                break
            case .pending:
                break
            @unknown default:
                break
            }
        } catch {
            errorMessage = error.localizedDescription
            AnalyticsService.log(
                AnalyticsService.Event.subscriptionPurchase,
                parameters: [
                    AnalyticsService.Param.productId: product.id,
                    AnalyticsService.Param.success: 0
                ]
            )
        }
    }

    /// 購入リストア（既存購入の復元）
    @MainActor
    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await updateSubscriptionStatus()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
