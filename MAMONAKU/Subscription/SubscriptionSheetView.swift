//
//  SubscriptionSheetView.swift
//  MAMONAKU
//
//  サブスクリプション購入・リストア用シート。
//

import SwiftUI
import StoreKit

struct SubscriptionSheetView: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if subscriptionManager.effectiveIsSubscribed {
                    Section {
                        Label("加入中です", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
                if let product = subscriptionManager.subscriptionProduct {
                    Section {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(product.displayName)
                                    .font(.headline)
                                Text(product.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(product.displayPrice)
                                .font(.headline.monospacedDigit())
                        }
                        .padding(.vertical, 4)
                    }
                } else {
                    Section {
                        Text("製品を読み込み中…")
                            .foregroundStyle(.secondary)
                    }
                }
                if let message = subscriptionManager.errorMessage {
                    Section {
                        Text(message)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
                Section {
                    Button {
                        Task {
                            await subscriptionManager.purchase()
                        }
                    } label: {
                        HStack {
                            Text("購入する")
                            Spacer()
                            if subscriptionManager.isPurchasing {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(subscriptionManager.isPurchasing || subscriptionManager.subscriptionProduct == nil)
                    Button("リストア") {
                        Task {
                            await subscriptionManager.restorePurchases()
                        }
                    }
                    .disabled(subscriptionManager.isPurchasing)
                }
            }
            .navigationTitle("サブスクリプション")
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
            Task {
                await subscriptionManager.loadProducts()
            }
        }
    }
}

#Preview {
    SubscriptionSheetView()
        .environmentObject(SubscriptionManager())
}
