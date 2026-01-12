import SwiftUI
import UIKit

private func isKeyboardVisible() -> Bool {
    // Check if keyboard is actually visible
    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let window = windowScene.windows.first else {
        return false
    }
    
    // Check if any text field is first responder
    if let _ = window.firstResponder as? UITextField {
        return true
    }
    if let _ = window.firstResponder as? UITextView {
        return true
    }
    
    return false
}

private func endEditing() {
    // Only dismiss if keyboard is actually visible to avoid RTI errors
    guard isKeyboardVisible() else { return }
    
    // Use a more gentle approach that doesn't interrupt input operations
    // Increased delay to allow emoji search operations to complete
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
        // Double-check keyboard is still visible before dismissing
        guard isKeyboardVisible() else { return }
        
        // First, try to resign first responder on the current first responder
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        
        // Then, as a fallback, end editing on the key window
        // Use false to allow animations to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }?
                .endEditing(false)
        }
    }
}

extension UIWindow {
    var firstResponder: UIResponder? {
        var responder: UIResponder? = self
        while let next = responder?.next {
            responder = next
            if responder is UITextField || responder is UITextView {
                return responder
            }
        }
        return nil
    }
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
        // Lower priority to not interfere with text field taps or system gestures
        tap.delaysTouchesBegan = false
        tap.delaysTouchesEnded = false
        // Allow simultaneous recognition with system gestures to prevent timeout
        tap.requiresExclusiveTouchType = false
        view.addGestureRecognizer(tap)
        tapRecognizer = tap
    }
    
    @objc private func handleGesture(_ gesture: UITapGestureRecognizer) {
        // Only dismiss if gesture is in ended state to avoid interrupting input
        guard gesture.state == .ended else { return }
        
        // Check if we're tapping on a text field or its superview - if so, don't dismiss
        let location = gesture.location(in: gesture.view)
        if let view = gesture.view?.hitTest(location, with: nil) {
            // Don't dismiss if tapping directly on a text field or control
            if view is UITextField || view is UITextView || view is UIControl {
                return
            }
            // Don't dismiss if tapping on a view that contains a text field
            if let _ = view.findSubview(ofType: UITextField.self) ?? view.findSubview(ofType: UITextView.self) {
                return
            }
        }
        
        // Call endEditing which now has built-in checks and delays
        endEditing()
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // Don't intercept touches on interactive elements (buttons, text fields, etc.)
        if let view = touch.view {
            // Allow system gestures to work first
            if view is UIControl || view.superview is UIControl {
                return false
            }
            // Don't block system gesture recognizers
            if let gestureRecognizers = view.gestureRecognizers {
                for gr in gestureRecognizers {
                    if gr is UIScreenEdgePanGestureRecognizer || 
                       gr is UIPanGestureRecognizer && gr.view is UIScrollView {
                        return false
                    }
                }
            }
        }
        return true
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Always allow simultaneous recognition to prevent blocking system gestures
        return true
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Don't require failure of system gestures - let them work first
        if otherGestureRecognizer is UIScreenEdgePanGestureRecognizer {
            return true
        }
        return false
    }
}

extension UIView {
    func findSubview<T: UIView>(ofType type: T.Type) -> T? {
        if let found = self as? T {
            return found
        }
        for subview in subviews {
            if let found = subview.findSubview(ofType: type) {
                return found
            }
        }
        return nil
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

// MARK: - Keyboard Toolbar
// Note: Global keyboard dismiss has been removed to prevent RTI errors.
// Use scrollDismissesKeyboard(.interactively) on ScrollViews instead.
// IMPORTANT: Apply this modifier INSIDE NavigationView contexts, not outside, to avoid duplicate toolbars.
extension View {
    func keyboardDoneToolbar() -> some View {
        self.toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    // Safe dismissal for toolbar button - user explicitly tapped "Done"
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
        }
    }
}

