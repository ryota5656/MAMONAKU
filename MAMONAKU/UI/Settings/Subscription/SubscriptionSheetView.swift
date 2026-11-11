import SwiftUI
import StoreKit

/// PLUS の購入・復元シート。製品一覧と購入処理は `SubscriptionManager` が持つ。
struct SubscriptionSheetView: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @State private var selectedProductID: String?

    private var products: [Product] {
        subscriptionManager.subscriptionProducts
    }

    private var selectedProduct: Product? {
        products.first(where: { $0.id == selectedProductID }) ?? products.first
    }

    private var selectedKind: SubscriptionPlanKind? {
        selectedProduct.map { SubscriptionPlanKind(product: $0) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    introduction
                    if subscriptionManager.effectiveIsSubscribed {
                        subscribedBadge
                    }
                    SubscriptionFeatureComparisonCard()
                    planList
                    if let message = subscriptionManager.errorMessage {
                        Text(message)
                            .foregroundStyle(.red)
                            .font(.caption)
                            .padding(.top, 4)
                    }
                    restoreButton
                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
            }
            .background(theme.background)
            .safeAreaInset(edge: .bottom) {
                purchaseBar
            }
            .navigationTitle("PLUSプラン")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            AnalyticsClient.logScreen(AnalyticsClient.Screen.subscription)
            selectDefaultPlanIfNeeded(from: products)
            Task {
                await subscriptionManager.loadProducts()
                await subscriptionManager.updateSubscriptionStatus()
            }
        }
        .onChange(of: subscriptionManager.subscriptionProducts) { _, products in
            selectDefaultPlanIfNeeded(from: products)
        }
    }

    // MARK: - Sections

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("PLUSでできること")
                .font(.title3.weight(.bold))
                .foregroundStyle(theme.textPrimary)
            Text("無料版との違いを確認して、期間限定の買い切り / 年額 / 月額プランを選択できます。（毎月コーヒー１杯分が、開発の励みになります）")
                .font(.subheadline)
                .foregroundStyle(theme.textSecondary)
        }
    }

    private var subscribedBadge: some View {
        HStack {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(.green)
            Text("加入中です")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.textPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)
                .fill(theme.surface)
        )
    }

    private var planList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("プランを選択")
                .font(.headline)
                .foregroundStyle(theme.textPrimary)

            if products.isEmpty {
                Text("プランを読み込み中…")
                    .font(.subheadline)
                    .foregroundStyle(theme.textSecondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(products, id: \.id) { product in
                    SubscriptionPlanItem(
                        kind: SubscriptionPlanKind(product: product),
                        displayName: product.displayName,
                        displayPrice: product.displayPrice,
                        isSelected: product.id == selectedProduct?.id,
                        onTap: { selectedProductID = product.id }
                    )
                }
            }
        }
    }

    private var restoreButton: some View {
        Button("購入を復元") {
            Task {
                await subscriptionManager.restorePurchases()
            }
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(theme.accent)
        .disabled(subscriptionManager.isPurchasing)
        .padding(.top, 4)
    }

    /// 画面下に固定する購入ボタン。
    private var purchaseBar: some View {
        VStack(spacing: 8) {
            Button {
                guard let product = selectedProduct else { return }
                Task {
                    await subscriptionManager.purchase(product: product)
                }
            } label: {
                HStack {
                    Text(SubscriptionPlanKind.purchaseButtonTitle(for: selectedKind))
                        .font(.headline.weight(.semibold))
                    Spacer()
                    if subscriptionManager.isPurchasing {
                        ProgressView()
                            .tint(theme.onAccent)
                    } else if let selectedProduct {
                        Text(selectedProduct.displayPrice)
                            .font(.subheadline.monospacedDigit().weight(.semibold))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .foregroundStyle(theme.onAccent)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(theme.accent)
                )
            }
            .disabled(subscriptionManager.isPurchasing || selectedProduct == nil)

            Text(SubscriptionPlanKind.purchaseFootnote(for: selectedKind))
                .font(.caption2)
                .foregroundStyle(theme.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }

    // MARK: - Private

    /// 選択中のプランが一覧に無ければ、買い切り → 年額 → 先頭 の順で選び直す。
    private func selectDefaultPlanIfNeeded(from products: [Product]) {
        if let selectedProductID, products.contains(where: { $0.id == selectedProductID }) {
            return
        }
        selectedProductID = products
            .min { lhs, rhs in
                SubscriptionPlanKind(product: lhs).defaultSelectionPriority
                    < SubscriptionPlanKind(product: rhs).defaultSelectionPriority
            }?
            .id
    }
}

#Preview {
    let settings = AppSettingsClient(defaults: UserDefaults(suiteName: "preview.subscription") ?? .standard)
    SubscriptionSheetView()
        .environmentObject(SubscriptionManager(settings: settings))
}
