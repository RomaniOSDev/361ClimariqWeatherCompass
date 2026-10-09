//
//  RootWindowPresenter.swift
//

import UIKit

final class RootWindowPresenter {

    private weak var window: UIWindow?

    init(window: UIWindow?) {
        self.window = window
    }

    /// Slides the incoming controller in from the trailing edge, then promotes it to root.
    func slide(to viewController: UIViewController, duration: TimeInterval = 0.35) {
        guard let window else { return }

        guard window.rootViewController != nil else {
            window.rootViewController = viewController
            window.makeKeyAndVisible()
            return
        }

        let incomingView = viewController.view!
        incomingView.frame = window.bounds
        incomingView.transform = CGAffineTransform(translationX: window.bounds.width, y: 0)
        window.addSubview(incomingView)

        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: [.curveEaseInOut],
            animations: {
                incomingView.transform = .identity
            },
            completion: { _ in
                incomingView.transform = .identity
                incomingView.removeFromSuperview()
                window.rootViewController = viewController
            }
        )
    }
}
