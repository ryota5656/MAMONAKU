import Quick
import Nimble
import StoreKit
@testable import MAMONAKU

final class SubscriptionPlanKindSpec: QuickSpec {
    override class func spec() {
        describe("SubscriptionPlanKind") {
            it("製品 ID からプランの種類を決める") {
                expect(SubscriptionPlanKind(productID: SubscriptionManager.plusLifetimeProductID, periodUnit: nil))
                    .to(equal(.lifetime))
                expect(SubscriptionPlanKind(productID: SubscriptionManager.subscriptionYearlyProductID, periodUnit: .month))
                    .to(equal(.yearly))
                expect(SubscriptionPlanKind(productID: SubscriptionManager.subscriptionMonthlyProductID, periodUnit: .year))
                    .to(equal(.monthly))
            }

            it("ID で判定できない製品は購読期間で決める") {
                let legacyID = SubscriptionManager.subscriptionLegacyProductID

                expect(SubscriptionPlanKind(productID: legacyID, periodUnit: .year)).to(equal(.yearly))
                expect(SubscriptionPlanKind(productID: legacyID, periodUnit: .month)).to(equal(.monthly))
                expect(SubscriptionPlanKind(productID: legacyID, periodUnit: .week)).to(equal(.other))
                expect(SubscriptionPlanKind(productID: legacyID, periodUnit: nil)).to(equal(.other))
            }

            it("買い切りには「期間限定」、年額には「おすすめ」のバッジを付ける") {
                expect(SubscriptionPlanKind.lifetime.badge).to(equal("期間限定"))
                expect(SubscriptionPlanKind.yearly.badge).to(equal("おすすめ"))
                expect(SubscriptionPlanKind.monthly.badge).to(beNil())
                expect(SubscriptionPlanKind.other.badge).to(beNil())
            }

            it("最初に選ぶプランは 買い切り → 年額 → それ以外 の順で優先する") {
                expect(SubscriptionPlanKind.lifetime.defaultSelectionPriority)
                    .to(beLessThan(SubscriptionPlanKind.yearly.defaultSelectionPriority))
                expect(SubscriptionPlanKind.yearly.defaultSelectionPriority)
                    .to(beLessThan(SubscriptionPlanKind.monthly.defaultSelectionPriority))
                expect(SubscriptionPlanKind.monthly.defaultSelectionPriority)
                    .to(equal(SubscriptionPlanKind.other.defaultSelectionPriority))
            }

            it("買い切りを選んでいるときだけ購入ボタンと補足の文言を変える") {
                expect(SubscriptionPlanKind.purchaseButtonTitle(for: .lifetime)).to(equal("期間限定 買い切りで購入"))
                expect(SubscriptionPlanKind.purchaseFootnote(for: .lifetime)).to(equal("期間限定の買い切りプランです"))

                expect(SubscriptionPlanKind.purchaseButtonTitle(for: .yearly)).to(equal("PLUSプランをはじめる"))
                expect(SubscriptionPlanKind.purchaseFootnote(for: .monthly)).to(equal("いつでもキャンセルできます"))
                expect(SubscriptionPlanKind.purchaseButtonTitle(for: nil)).to(equal("PLUSプランをはじめる"))
                expect(SubscriptionPlanKind.purchaseFootnote(for: nil)).to(equal("いつでもキャンセルできます"))
            }
        }
    }
}
