import SwiftUI
import UniformTypeIdentifiers

struct TimelineDropDelegate: DropDelegate {
    let hourHeight: CGFloat
    let minuteStep: Int
    let timelineHeight: CGFloat
    @Binding var preview: TimelineItem?
    @Binding var previewItemID: UUID?
    @Binding var dragItemID: UUID?
    let onPreview: (UUID, CGPoint) -> Void
    let onDrop: (UUID, CGPoint) -> Void
    @State private var isLoadingItemID = false

//    func dropEntered(info: DropInfo) {
//        loadDurationIfNeeded(from: info)
//    }

    func performDrop(info: DropInfo) -> Bool {
        defer {
            DispatchQueue.main.async {
                preview = nil
                previewItemID = nil
                dragItemID = nil
            }
        }

        guard let provider = info.itemProviders(for: [UTType.text]).first else { return false }

        provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { item, _ in
            guard let itemID = parseItemID(from: item) else { return }

            DispatchQueue.main.async {
                let location = info.location
                onDrop(itemID, location)
            }
        }
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        if let itemID = previewItemID ?? dragItemID {
            onPreview(itemID, info.location)
        } else {
            loadItemIDIfNeeded(from: info)
        }
        return DropProposal(operation: .copy)
    }

    func dropExited(info: DropInfo) {
        preview = nil
        previewItemID = nil
    }

    private func loadItemIDIfNeeded(from info: DropInfo) {
        guard !isLoadingItemID, previewItemID == nil,
              let provider = info.itemProviders(for: [UTType.text]).first
        else { return }

        isLoadingItemID = true
        provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { item, _ in
            defer { isLoadingItemID = false }
            guard let itemID = parseItemID(from: item) else { return }

            DispatchQueue.main.async {
                previewItemID = itemID
                onPreview(itemID, info.location)
            }
        }
    }

    private func parseItemID(from item: NSSecureCoding?) -> UUID? {
        if let data = item as? Data,
           let text = String(data: data, encoding: .utf8) {
            return UUID(uuidString: text.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        if let text = item as? String {
            return UUID(uuidString: text.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        if let text = item as? NSString {
            return UUID(uuidString: text.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return nil
    }
}
