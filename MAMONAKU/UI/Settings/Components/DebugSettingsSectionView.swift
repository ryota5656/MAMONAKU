#if DEBUG
import SwiftUI

/// DEBUG ビルド専用の開発者向け設定。
struct DebugSettingsSectionView: View {
    let primary: Color
    let secondary: Color
    let listBackground: Color
    @Binding var debugOverrideSubscribed: Bool

    var body: some View {
        Section {
            Toggle(isOn: $debugOverrideSubscribed) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("PLUS 加入をシミュレート")
                        .foregroundStyle(primary)
                    Text("StoreKit の購入状態に関係なく PLUS 機能を有効化")
                        .font(.caption)
                        .foregroundStyle(secondary)
                }
            }
            .tint(.orange)
        } header: {
            Text("デバッグ")
                .foregroundStyle(secondary)
        } footer: {
            Text("リリースビルドでは表示されません。")
                .foregroundStyle(secondary)
        }
        .listRowBackground(listBackground)
    }
}
#endif
