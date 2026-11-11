import SwiftUI
import UniformTypeIdentifiers

/// 1 日分のタイムラインへのドロップを受け取り、起きたことをクロージャで通知する。
/// 位置はタイムライン上端からの距離（pt）。
struct TimelineDropDelegate: DropDelegate {
    /// ドラッグ中の予定。分からない場合（nil）は、ドロップ内容から読み取って `onIdentify` で通知する。
    let draggingItemID: UUID?
    let onIdentify: (UUID) -> Void
    /// ドラッグしたままタイムライン上を動いている
    let onHover: (UUID, CGFloat) -> Void
    /// ドラッグしたままタイムラインの外へ出た
    let onExit: () -> Void
    /// タイムライン上で指を離した
    let onDrop: (UUID, CGFloat) -> Void
    /// ドロップ操作が終わった（`onDrop` より先に呼ばれる）
    let onFinish: () -> Void

    func dropUpdated(info: DropInfo) -> DropProposal? {
        let y = info.location.y
        if let draggingItemID {
            onHover(draggingItemID, y)
        } else {
            loadItemID(from: info) { itemID in
                onIdentify(itemID)
                onHover(itemID, y)
            }
        }
        return DropProposal(operation: .copy)
    }

    func dropExited(info: DropInfo) {
        onExit()
    }

    func performDrop(info: DropInfo) -> Bool {
        DispatchQueue.main.async {
            onFinish()
        }

        let y = info.location.y
        return loadItemID(from: info) { itemID in
            onDrop(itemID, y)
        }
    }

    /// ドロップ内容から予定の ID を読み取り、メインスレッドで `completion` を呼ぶ。
    /// - Returns: 読み取りを開始できたか。
    @discardableResult
    private func loadItemID(from info: DropInfo, completion: @escaping (UUID) -> Void) -> Bool {
        guard let provider = info.itemProviders(for: [UTType.text]).first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { item, _ in
            guard let itemID = ItemDragPayload.itemID(from: item) else { return }
            DispatchQueue.main.async {
                completion(itemID)
            }
        }
        return true
    }
}
