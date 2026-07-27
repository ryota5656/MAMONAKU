import SwiftUI
import UIKit

/// 長押しで位置（Y）を取得（スクロールと併用できるよう UIKit で取得）
struct LongPressLocationView: UIViewRepresentable {
    var onLongPress: (CGFloat) -> Void

    func makeUIView(context: Context) -> UIView {
        let v = UIView()
        v.backgroundColor = .clear
        let longPress = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.didLongPress(_:)))
        longPress.minimumPressDuration = 0.5
        longPress.delaysTouchesBegan = false
        v.addGestureRecognizer(longPress)
        return v
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onLongPress = onLongPress
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onLongPress: onLongPress)
    }

    final class Coordinator: NSObject {
        var onLongPress: (CGFloat) -> Void

        init(onLongPress: @escaping (CGFloat) -> Void) {
            self.onLongPress = onLongPress
        }

        @objc func didLongPress(_ g: UILongPressGestureRecognizer) {
            guard g.state == .began else { return }
            let y = g.location(in: g.view).y
            onLongPress(y)
        }
    }
}

