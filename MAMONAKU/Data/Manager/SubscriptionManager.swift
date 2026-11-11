import Foundation
import Combine
import StoreKit

/// PLUS 利用権の状態。StoreKit 2 のサブスクリプション / 買い切り製品と紐づく。
///
/// 加入状態は `AppSettingsClient.isSubscribed` にも書き出し、
/// 画面を持たない処理（カレンダー同期・通知・Live Activity）が参照できるようにする。
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

    /// 購入処理中
    @Published private(set) var isPurchasing: Bool = false

    /// エラーメッセージ（購入失敗時など）
    @Published var errorMessage: String?

    private let settings: AppSettingsClient
    private var updateTask: Task<Void, Never>?
    private var listenerTask: Task<Void, Never>?

    init(settings: AppSettingsClient) {
        self.settings = settings
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

            hasEntitlement = true
            break
        }
        if isSubscribed != hasEntitlement {
            isSubscribed = hasEntitlement
        }
    }

    private func persistSubscriptionState() {
        settings.isSubscribed = effectiveIsSubscribed
    }

    /// トランザクション更新の監視（購入・更新・失効など）
    private func listenTransactionUpdates() async {
        for await result in Transaction.updates {
            guard case .verified(let transaction) = result,
                  Self.subscriptionProductIDs.contains(transaction.productID)
            else { continue }
            await updateSubscriptionStatus()
        }
    }

    /// 購入 UI での並び順。`subscriptionProductIDs` の順に従う。
    private static func preferredSortOrder(for id: String) -> Int {
        subscriptionProductIDs.firstIndex(of: id) ?? subscriptionProductIDs.count
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
                    logPurchase(productID: product.id, success: true)
                case .unverified:
                    errorMessage = "検証に失敗しました"
                    logPurchase(productID: product.id, success: false)
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
            logPurchase(productID: product.id, success: false)
        }
    }

    private func logPurchase(productID: String, success: Bool) {
        AnalyticsClient.log(
            AnalyticsClient.Event.subscriptionPurchase,
            parameters: [
                AnalyticsClient.Param.productId: productID,
                AnalyticsClient.Param.success: success ? 1 : 0
            ]
        )
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
