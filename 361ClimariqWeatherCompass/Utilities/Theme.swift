import SwiftUI
import UIKit

extension View {
    func canvasBackground(_ image: String = "bg_asphalt") -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                Color("AppBackground")
                    .overlay {
                        Image(image)
                            .resizable()
                            .scaledToFill()
                            .opacity(0.12)
                    }
                    .overlay { TechGrid() }
                    .clipped()
                    .ignoresSafeArea()
            }
    }
}

enum Haptics {
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

enum Keyboard {
    static func dismiss() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    static func dismissOnTap(in window: UIWindow) {
        TapSink.shared.attach(to: window)
    }

    fileprivate final class TapSink: NSObject, UIGestureRecognizerDelegate {
        static let shared = TapSink()

        func attach(to window: UIWindow) {
            if window.gestureRecognizers?.contains(where: { $0.name == "climariq.keyboard.dismiss" }) == true {
                return
            }
            let tap = UITapGestureRecognizer(target: self, action: #selector(resign))
            tap.name = "climariq.keyboard.dismiss"
            tap.cancelsTouchesInView = false
            tap.delegate = self
            window.addGestureRecognizer(tap)
        }

        @objc private func resign() {
            Keyboard.dismiss()
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            var node = touch.view
            while let view = node {
                if view is UITextField || view is UITextView || view is UISearchBar {
                    return false
                }
                node = view.superview
            }
            return true
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            true
        }
    }
}

struct TechGrid: View {
    var body: some View {
        Canvas { context, size in
            var path = Path()
            let step: CGFloat = 22
            var x: CGFloat = 0
            while x < size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += step
            }
            var y: CGFloat = 0
            while y < size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += step
            }
            context.stroke(path, with: .color(Color.white.opacity(0.05)), lineWidth: 0.5)
        }
        .allowsHitTesting(false)
    }
}
