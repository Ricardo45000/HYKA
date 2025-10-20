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
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleGesture))
        tap.cancelsTouchesInView = false
        tap.delegate = self
        view.addGestureRecognizer(tap)
        tapRecognizer = tap
        
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleGesture))
        pan.cancelsTouchesInView = false
        pan.delegate = self
        view.addGestureRecognizer(pan)
        panRecognizer = pan
    }
    
    @objc private func handleGesture() {
        endEditing()
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
        DispatchQueue.main.async {
            if let superview = view.superview {
                context.coordinator.attach(to: superview)
            }
        }
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let superview = uiView.superview {
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

