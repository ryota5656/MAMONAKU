import Foundation

/// ドラッグ＆ドロップで受け渡す内容。予定の ID を文字列として運ぶ。
nonisolated enum ItemDragPayload {
    /// ドラッグ開始時に渡す内容を作る。
    static func itemProvider(for itemID: UUID) -> NSItemProvider {
        NSItemProvider(object: itemID.uuidString as NSString)
    }

    /// ドロップされた内容（`NSItemProvider.loadItem` の結果）から予定の ID を読み取る。
    static func itemID(from item: NSSecureCoding?) -> UUID? {
        if let data = item as? Data {
            return itemID(from: String(data: data, encoding: .utf8))
        }
        return itemID(from: item as? String)
    }

    /// 文字列から予定の ID を読み取る。
    static func itemID(from text: String?) -> UUID? {
        guard let text else { return nil }
        return UUID(uuidString: text.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
