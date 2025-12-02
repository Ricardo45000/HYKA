import SwiftUI
import UIKit

private func endEditing() {
    UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .flatMap { $0.windows }
        .first { $0.isKeyWindow }?
        .endEditing(true)
}

private final class KeyboardDismissCoordinator: NSObject, UIGestureRecognizerDelegate {
    weak var hostView: UIView?
    var tapRecognizer: UITapGestureRecognizer?
    var panRecognizer: UIPanGestureRecognizer?
    
    func attach(to view: UIView) {
        guard tapRecognizer == nil, panRecognizer == nil else { return }
        hostView = view
        
        // Only add tap recognizer - pan can cause delays
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleGesture))
        tap.cancelsTouchesInView = false
        tap.delegate = self
        // Lower priority to not interfere with text field taps
        tap.delaysTouchesBegan = false
        tap.delaysTouchesEnded = false
        view.addGestureRecognizer(tap)
        tapRecognizer = tap
    }
    
    @objc private func handleGesture() {
        endEditing()
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // Don't intercept touches on interactive elements (buttons, text fields, etc.)
        if let view = touch.view {
            return !(view is UIControl) && !(view.superview is UIControl)
        }
        return true
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }
}

private struct KeyboardDismissInstaller: UIViewRepresentable {
    func makeCoordinator() -> KeyboardDismissCoordinator {
        KeyboardDismissCoordinator()
    }
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false // Don't intercept touches, just install gesture recognizers
        // Use async to avoid blocking initial layout
        DispatchQueue.main.async {
            if let superview = view.superview {
                context.coordinator.attach(to: superview)
            }
        }
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Only attach if not already attached to avoid duplicate recognizers
        if context.coordinator.tapRecognizer == nil, let superview = uiView.superview {
            context.coordinator.attach(to: superview)
        }
    }
}

struct GlobalKeyboardDismissModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.background(KeyboardDismissInstaller())
    }
}

extension View {
    func globalKeyboardDismiss() -> some View {
        modifier(GlobalKeyboardDismissModifier())
    }
    
    func keyboardDoneToolbar() -> some View {
        self.toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    endEditing()
                }
            }
        }
    }
}

