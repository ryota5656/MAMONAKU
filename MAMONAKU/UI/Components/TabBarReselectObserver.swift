import SwiftUI
import UIKit

/// 同じタブの再タップを検知する。
/// `UITabBarController.delegate` は奪わない（SwiftUI の選択復元が壊れるため）。
struct TabBarReselectObserver: UIViewControllerRepresentable {
    /// 再選択されたタブの index（0-based）
    var onReselect: (Int) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onReselect: onReselect)
    }

    func makeUIViewController(context: Context) -> ProbeViewController {
        let controller = ProbeViewController()
        controller.onAppearInWindow = { [weak coordinator = context.coordinator] host in
            coordinator?.scheduleAttach(from: host)
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: ProbeViewController, context: Context) {
        context.coordinator.onReselect = onReselect
        context.coordinator.scheduleAttach(from: uiViewController)
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onReselect: (Int) -> Void
        private weak var observedTabBar: UITabBar?
        private let gestureName = "mamonaku.tab.reselect"
        private var attachWorkItem: DispatchWorkItem?

        init(onReselect: @escaping (Int) -> Void) {
            self.onReselect = onReselect
        }

        func scheduleAttach(from host: UIViewController) {
            attachWorkItem?.cancel()
            // Tab 構築直後は tabBar が未接続なことがあるので数回リトライする
            let delays: [TimeInterval] = [0, 0.15, 0.5, 1.0]
            for delay in delays {
                let work = DispatchWorkItem { [weak self, weak host] in
                    guard let self, let host else { return }
                    self.attach(from: host)
                }
                attachWorkItem = work
                DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
            }
        }

        func attach(from host: UIViewController) {
            let tabBar = host.findTabBarController()?.tabBar
                ?? Self.findTabBarControllerFromScenes()?.tabBar
                ?? Self.findTabBarInKeyWindow()
            guard let tabBar else { return }

            if observedTabBar !== tabBar {
                observedTabBar = tabBar
            }

            installGesture(on: tabBar)
            if let container = tabBar.superview {
                installGesture(on: container)
            }
        }

        private func installGesture(on view: UIView) {
            if view.gestureRecognizers?.contains(where: { $0.name == gestureName }) == true {
                return
            }
            let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            tap.name = gestureName
            tap.cancelsTouchesInView = false
            tap.delegate = self
            view.addGestureRecognizer(tap)
        }

        @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
            guard gesture.state == .ended else { return }
            guard let tabBar = observedTabBar ?? Self.findTabBarControllerFromScenes()?.tabBar else { return }

            let locationInTabBar = gesture.location(in: tabBar)
            // コンテナ側に付けたジェスチャでも、タブバー座標で判定する
            guard tabBar.bounds.insetBy(dx: 0, dy: -20).contains(locationInTabBar) else { return }
            guard isTapOnTimelineTab(location: locationInTabBar, tabBar: tabBar) else { return }

            // タイムラインタブ（先頭）への再タップだけ扱う。
            // selectedIndex が取れない新UIでも、先頭ボタンヒットなら発火する。
            if let selectedIndex = Self.findTabBarControllerFromScenes()?.selectedIndex,
               selectedIndex != 0 {
                return
            }

            DispatchQueue.main.async { [onReselect] in
                onReselect(0)
            }
        }

        /// Liquid Glass でも動くよう、実ボタン frame → 左寄りのフォールバックの順で判定する。
        private func isTapOnTimelineTab(location: CGPoint, tabBar: UITabBar) -> Bool {
            let buttons = tabBar.subviews
                .filter { view in
                    let name = String(describing: type(of: view))
                    return name.contains("Button") || view is UIControl
                }
                .filter { !$0.isHidden && $0.alpha > 0.01 && $0.frame.width > 10 }
                .sorted { $0.frame.minX < $1.frame.minX }

            if let first = buttons.first {
                return first.frame.insetBy(dx: -8, dy: -8).contains(location)
            }

            // search 役割タブは右寄せになりやすいので、左 1/3 をタイムラインとみなす
            return location.x < tabBar.bounds.width / 3
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }

        private static func findTabBarControllerFromScenes() -> UITabBarController? {
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            for scene in scenes {
                for window in scene.windows where !window.isHidden {
                    if let tab = window.rootViewController?.findTabBarControllerInHierarchy() {
                        return tab
                    }
                }
            }
            return nil
        }

        private static func findTabBarInKeyWindow() -> UITabBar? {
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            for scene in scenes {
                for window in scene.windows where !window.isHidden {
                    if let bar = findTabBar(in: window) { return bar }
                }
            }
            return nil
        }

        private static func findTabBar(in view: UIView) -> UITabBar? {
            if let bar = view as? UITabBar { return bar }
            for subview in view.subviews {
                if let bar = findTabBar(in: subview) { return bar }
            }
            return nil
        }
    }

    final class ProbeViewController: UIViewController {
        var onAppearInWindow: ((UIViewController) -> Void)?

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            view.isUserInteractionEnabled = false
            view.backgroundColor = .clear
            onAppearInWindow?(self)
        }
    }
}

private extension UIViewController {
    func findTabBarController() -> UITabBarController? {
        var current: UIViewController? = self
        while let c = current {
            if let tab = c as? UITabBarController { return tab }
            if let tab = c.tabBarController { return tab }
            current = c.parent
        }
        return self.view.window?.rootViewController?.findTabBarControllerInHierarchy()
    }

    func findTabBarControllerInHierarchy() -> UITabBarController? {
        if let tab = self as? UITabBarController { return tab }
        for child in children {
            if let tab = child.findTabBarControllerInHierarchy() { return tab }
        }
        if let presented = presentedViewController {
            return presented.findTabBarControllerInHierarchy()
        }
        return nil
    }
}
