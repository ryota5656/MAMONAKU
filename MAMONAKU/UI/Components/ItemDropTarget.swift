import SwiftUI
import UniformTypeIdentifiers
import UIKit

/// UIKit の UIDropInteraction でドロップを受け取る（SwiftUI の onDrop が効かない場合のフォールバック）
struct ItemDropTarget: UIViewRepresentable {
    let onDrop: (UUID) -> Void
    var onDragEntered: (() -> Void)? = nil
    var onDragExited: (() -> Void)? = nil

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.addInteraction(UIDropInteraction(delegate: context.coordinator))
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onDrop = onDrop
        context.coordinator.onDragEntered = onDragEntered
        context.coordinator.onDragExited = onDragExited
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onDrop: onDrop, onDragEntered: onDragEntered, onDragExited: onDragExited)
    }

    final class Coordinator: NSObject, UIDropInteractionDelegate {
        var onDrop: (UUID) -> Void
        var onDragEntered: (() -> Void)?
        var onDragExited: (() -> Void)?

        init(onDrop: @escaping (UUID) -> Void, onDragEntered: (() -> Void)?, onDragExited: (() -> Void)?) {
            self.onDrop = onDrop
            self.onDragEntered = onDragEntered
            self.onDragExited = onDragExited
        }

        func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
            session.canLoadObjects(ofClass: NSString.self) || session.hasItemsConforming(toTypeIdentifiers: [UTType.text.identifier])
        }

        func dropInteraction(_ interaction: UIDropInteraction, sessionDidEnter session: UIDropSession) {
            DispatchQueue.main.async { [weak self] in
                self?.onDragEntered?()
            }
        }

        func dropInteraction(_ interaction: UIDropInteraction, sessionDidExit session: UIDropSession) {
            DispatchQueue.main.async { [weak self] in
                self?.onDragExited?()
            }
        }

        func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal {
            UIDropProposal(operation: .move)
        }

        func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
            guard let item = session.items.first else { return }
            let provider = item.itemProvider

            func complete(with id: UUID?) {
                guard let id else { return }
                DispatchQueue.main.async { [weak self] in
                    self?.onDrop(id)
                }
            }

            if provider.canLoadObject(ofClass: NSString.self) {
                provider.loadObject(ofClass: NSString.self) { object, _ in
                    let id = (object as? String).flatMap { UUID(uuidString: $0.trimmingCharacters(in: .whitespacesAndNewlines)) }
                    complete(with: id)
                }
                return
            }

            provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { item, _ in
                let id: UUID? = {
                    if let data = item as? Data, let text = String(data: data, encoding: .utf8) {
                        return UUID(uuidString: text.trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                    if let text = item as? String { return UUID(uuidString: text.trimmingCharacters(in: .whitespacesAndNewlines)) }
                    if let text = item as? NSString { return UUID(uuidString: text.trimmingCharacters(in: .whitespacesAndNewlines) as String) }
                    return nil
                }()
                complete(with: id)
            }
        }
    }
}

