import StoreKit

/// PLUS の購入プランの種類。プラン名・バッジ・購入ボタンの文言を決める。
enum SubscriptionPlanKind: Equatable {
    /// 期間限定の買い切り
    case lifetime
    case yearly
    case monthly
    /// 上記のどれにも当てはまらない製品（旧製品 ID など）
    case other

    /// 製品 ID から判定する。未知の ID は購読期間（年 / 月）で判定する。
    init(productID: String, periodUnit: Product.SubscriptionPeriod.Unit?) {
        switch productID {
        case SubscriptionManager.plusLifetimeProductID:
            self = .lifetime
        case SubscriptionManager.subscriptionYearlyProductID:
            self = .yearly
        case SubscriptionManager.subscriptionMonthlyProductID:
            self = .monthly
        default:
            switch periodUnit {
            case .year: self = .yearly
            case .month: self = .monthly
            default: self = .other
            }
        }
    }

    init(product: Product) {
        self.init(productID: product.id, periodUnit: product.subscription?.subscriptionPeriod.unit)
    }

    var label: String {
        switch self {
        case .lifetime: return "買い切りプラン"
        case .yearly: return "年額プラン"
        case .monthly: return "月額プラン"
        case .other: return "PLUSプラン"
        }
    }

    /// プラン名の横に出す強調バッジ。
    var badge: String? {
        switch self {
        case .lifetime: return "期間限定"
        case .yearly: return "おすすめ"
        case .monthly, .other: return nil
        }
    }

    /// 最初に選択状態にする優先度（小さいほど優先）。買い切り → 年額 → それ以外の順。
    var defaultSelectionPriority: Int {
        switch self {
        case .lifetime: return 0
        case .yearly: return 1
        case .monthly, .other: return 2
        }
    }

    /// 購入ボタンの文言。プラン未選択（nil）のときは購読プランと同じ文言にする。
    static func purchaseButtonTitle(for kind: SubscriptionPlanKind?) -> String {
        kind == .lifetime ? "期間限定 買い切りで購入" : "PLUSプランをはじめる"
    }

    /// 購入ボタン下の補足。
    static func purchaseFootnote(for kind: SubscriptionPlanKind?) -> String {
        kind == .lifetime ? "期間限定の買い切りプランです" : "いつでもキャンセルできます"
    }
}
