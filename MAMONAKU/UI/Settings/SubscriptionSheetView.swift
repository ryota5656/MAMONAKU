//
//  SubscriptionSheetView.swift
//  MAMONAKU
//
//  サブスクリプション購入・リストア用シート。
//

import SwiftUI
import StoreKit

struct SubscriptionSheetView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProductID: String?

    private var products: [Product] {
        subscriptionManager.subscriptionProducts
    }

    private var selectedProduct: Product? {
        guard let selectedProductID else { return products.first }
        return products.first(where: { $0.id == selectedProductID }) ?? products.first
    }

    var body: some View {
        let primary = AppColors.textPrimary(palette: themeManager.theme, environmentScheme: colorScheme)
        let secondary = AppColors.textSecondary(palette: themeManager.theme, environmentScheme: colorScheme)
        let accent = AppColors.accent(palette: themeManager.theme, environmentScheme: colorScheme)
        let background = AppColors.background(palette: themeManager.theme, environmentScheme: colorScheme)
        let cardBackground = AppColors.settingsListBackground(palette: themeManager.theme, environmentScheme: colorScheme)

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("PLUSでできること")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(primary)
                        Text("無料版との違いを確認して、期間限定の買い切り / 年額 / 月額プランを選択できます。（毎月コーヒー１杯分が、開発の励みになります）")
                            .font(.subheadline)
                            .foregroundStyle(secondary)
                    }

                    if subscriptionManager.effectiveIsSubscribed {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(.green)
                            Text("加入中です")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(primary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(cardBackground)
                        )
                    }

                    featureComparisonCard(
                        primary: primary,
                        secondary: secondary,
                        cardBackground: cardBackground
                    )

                    VStack(alignment: .leading, spacing: 10) {
                        Text("プランを選択")
                            .font(.headline)
                            .foregroundStyle(primary)

                        if products.isEmpty {
                            Text("プランを読み込み中…")
                                .font(.subheadline)
                                .foregroundStyle(secondary)
                                .padding(.vertical, 8)
                        } else {
                            ForEach(products, id: \.id) { product in
                                planRow(
                                    product: product,
                                    primary: primary,
                                    secondary: secondary,
                                    accent: accent,
                                    cardBackground: cardBackground
                                )
                            }
                        }
                    }

                    if let message = subscriptionManager.errorMessage {
                        Text(message)
                            .foregroundStyle(.red)
                            .font(.caption)
                            .padding(.top, 4)
                    }

                    Button("購入を復元") {
                        Task {
                            await subscriptionManager.restorePurchases()
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(accent)
                    .disabled(subscriptionManager.isPurchasing)
                    .padding(.top, 4)

                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
            }
            .background(background)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    Button {
                        guard let product = selectedProduct else { return }
                        Task {
                            await subscriptionManager.purchase(product: product)
                        }
                    } label: {
                        HStack {
                            Text(purchaseButtonTitle)
                                .font(.headline.weight(.semibold))
                            Spacer()
                            if subscriptionManager.isPurchasing {
                                ProgressView()
                                    .tint(AppColors.onAccent(palette: themeManager.theme, environmentScheme: colorScheme))
                            } else if let selectedProduct {
                                Text(selectedProduct.displayPrice)
                                    .font(.subheadline.monospacedDigit().weight(.semibold))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .foregroundStyle(AppColors.onAccent(palette: themeManager.theme, environmentScheme: colorScheme))
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(accent)
                        )
                    }
                    .disabled(subscriptionManager.isPurchasing || selectedProduct == nil)

                    Text(purchaseFootnote)
                        .font(.caption2)
                        .foregroundStyle(secondary)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 8)
                .background(.ultraThinMaterial)
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
            AnalyticsService.logScreen(AnalyticsService.Screen.subscription)
            applyDefaultSelectionIfNeeded(from: subscriptionManager.subscriptionProducts)
            Task {
                await subscriptionManager.loadProducts()
                await subscriptionManager.updateSubscriptionStatus()
            }
        }
        .onChange(of: subscriptionManager.subscriptionProducts) { _, products in
            applyDefaultSelectionIfNeeded(from: products)
        }
    }

    private func applyDefaultSelectionIfNeeded(from products: [Product]) {
        guard !products.isEmpty else {
            selectedProductID = nil
            return
        }
        if let selectedProductID, products.contains(where: { $0.id == selectedProductID }) {
            return
        }
        selectedProductID = products.first(where: { $0.id == SubscriptionManager.plusLifetimeProductID })?.id
            ?? products.first(where: { planLabel(for: $0) == "年額プラン" })?.id
            ?? products.first?.id
    }

    private func planRow(
        product: Product,
        primary: Color,
        secondary: Color,
        accent: Color,
        cardBackground: Color
    ) -> some View {
        let isSelected = product.id == selectedProduct?.id
        return Button {
            selectedProductID = product.id
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(planLabel(for: product))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(primary)
                        if let badge = planBadge(for: product) {
                            Text(badge)
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .foregroundStyle(AppColors.onAccent(palette: themeManager.theme, environmentScheme: colorScheme))
                                .background(
                                    Capsule()
                                        .fill(accent)
                                )
                        }
                    }
                    Text(product.displayName)
                        .font(.caption)
                        .foregroundStyle(secondary)
                }
                Spacer()
                Text(product.displayPrice)
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .foregroundStyle(primary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? accent : secondary.opacity(0.25), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func featureComparisonCard(primary: Color, secondary: Color, cardBackground: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            comparisonRow(title: "テーマ選択", free: "System / Light / Dark", plus: "全テーマ利用", primary: primary, secondary: secondary)
            comparisonRow(title: "標準カレンダー同期", free: "利用不可", plus: "利用可能", primary: primary, secondary: secondary)
            comparisonRow(title: "開始通知", free: "オン/オフ", plus: "オン/オフ", primary: primary, secondary: secondary)
//            comparisonRow(title: "Dynamic Island表示", free: "利用不可", plus: "オン/オフ", primary: primary, secondary: secondary)
            comparisonRow(title: "複数Live Activity表示", free: "利用不可", plus: "オン/オフ", primary: primary, secondary: secondary)
            comparisonRow(title: "バッファ通知", free: "利用不可", plus: "オン/オフ + 分数設定", primary: primary, secondary: secondary)
            comparisonRow(title: "優先度設定", free: "Lowのみ", plus: "Low / Medium / High", primary: primary, secondary: secondary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(cardBackground)
        )
    }

    private func comparisonRow(title: String, free: String, plus: String, primary: Color, secondary: Color) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(primary)
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text("無料: \(free)")
                    .font(.caption)
                    .foregroundStyle(secondary)
                Text("PLUS: \(plus)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(primary)
            }
        }
    }

    private func planLabel(for product: Product) -> String {
        if product.id == SubscriptionManager.plusLifetimeProductID { return "買い切りプラン" }
        if product.id == SubscriptionManager.subscriptionYearlyProductID { return "年額プラン" }
        if product.id == SubscriptionManager.subscriptionMonthlyProductID { return "月額プラン" }
        if let period = product.subscription?.subscriptionPeriod {
            switch period.unit {
            case .year:
                return "年額プラン"
            case .month:
                return "月額プラン"
            default:
                break
            }
        }
        return "PLUSプラン"
    }

    private var purchaseButtonTitle: String {
        guard let selectedProduct else { return "PLUSプランをはじめる" }
        if selectedProduct.id == SubscriptionManager.plusLifetimeProductID {
            return "期間限定 買い切りで購入"
        }
        return "PLUSプランをはじめる"
    }

    private var purchaseFootnote: String {
        guard selectedProduct?.id == SubscriptionManager.plusLifetimeProductID else {
            return "いつでもキャンセルできます"
        }
        return "期間限定の買い切りプランです"
    }

    private func planBadge(for product: Product) -> String? {
        if product.id == SubscriptionManager.plusLifetimeProductID { return "期間限定" }
        if planLabel(for: product) == "年額プラン" { return "おすすめ" }
        return nil
    }
}

#Preview {
    SubscriptionSheetView()
        .environmentObject(SubscriptionManager())
        .environmentObject(ThemeManager())
}
