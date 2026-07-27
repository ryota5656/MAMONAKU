import SwiftUI

struct AccountSectionView: View {
    let primary: Color
    let secondary: Color
    let listBackground: Color
    let subscriptionStatusText: String
    let onTapSubscription: () -> Void

    var body: some View {
        Section {
            Button(action: onTapSubscription) {
                HStack(spacing: 12) {
                    Image(systemName: "crown.fill")
                        .font(.body)
                        .foregroundStyle(.yellow)
                        .frame(width: 28, alignment: .center)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("サブスクリプション")
                            .foregroundStyle(primary)
                        Text(subscriptionStatusText)
                            .font(.caption)
                            .foregroundStyle(secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(secondary)
                }
            }
            .buttonStyle(.plain)
        } header: {
            Text("アカウント")
                .foregroundStyle(secondary)
        }
        .listRowBackground(listBackground)
    }
}

