import SwiftUI
import UIKit

/// 長押し開始位置と、押し続けたままのドラッグ Y を取得する（スクロールと併用できるよう UIKit で取得）。
struct LongPressLocationView: UIViewRepresentable {
    var onBegan: (CGFloat) -> Void
    var onChanged: (CGFloat) -> Void
    var onEnded: (CGFloat) -> Void
    var onCancelled: () -> Void

    func makeUIView(context: Context) -> UIView {
        let v = UIView()
        v.backgroundColor = .clear
        let longPress = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.didLongPress(_:))
        )
        longPress.minimumPressDuration = 0.5
        longPress.allowableMovement = .greatestFiniteMagnitude
        longPress.delaysTouchesBegan = false
        v.addGestureRecognizer(longPress)
        return v
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onBegan = onBegan
        context.coordinator.onChanged = onChanged
        context.coordinator.onEnded = onEnded
        context.coordinator.onCancelled = onCancelled
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onBegan: onBegan,
            onChanged: onChanged,
            onEnded: onEnded,
            onCancelled: onCancelled
        )
    }

    final class Coordinator: NSObject {
        var onBegan: (CGFloat) -> Void
        var onChanged: (CGFloat) -> Void
        var onEnded: (CGFloat) -> Void
        var onCancelled: () -> Void

        init(
            onBegan: @escaping (CGFloat) -> Void,
            onChanged: @escaping (CGFloat) -> Void,
            onEnded: @escaping (CGFloat) -> Void,
            onCancelled: @escaping () -> Void
        ) {
            self.onBegan = onBegan
            self.onChanged = onChanged
            self.onEnded = onEnded
            self.onCancelled = onCancelled
        }

        @objc func didLongPress(_ g: UILongPressGestureRecognizer) {
            let y = g.location(in: g.view).y
            switch g.state {
            case .began:
                onBegan(y)
            case .changed:
                onChanged(y)
            case .ended:
                onEnded(y)
            case .cancelled, .failed:
                onCancelled()
            default:
                break
            }
        }
    }
}
