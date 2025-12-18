import Foundation
import SwiftUI
import Combine

/// Centralized error manager for the entire app
/// Handles error display and provides user-friendly error messages
@MainActor
final class ErrorManager: ObservableObject {
    static let shared = ErrorManager()
    
    @Published var currentError: AppError?
    @Published var showError = false
    
    private init() {}
    
    /// Show an error in the app UI
    func showError(_ error: Error, title: String? = nil) {
        // Ignore cancellation errors (these are not real errors)
        if let urlError = error as? URLError, urlError.code == .cancelled {
            print("ℹ️ Ignoring cancelled request error")
            return
        }
        
        // Check for NSURLErrorDomain code -999 (cancelled)
        let errorString = String(describing: error)
        if errorString.contains("Code=-999") || errorString.contains("cancelled") {
            print("ℹ️ Ignoring cancelled request error")
            return
        }
        
        let appError = AppError.from(error, title: title)
        currentError = appError
        showError = true
        
        // Log error for debugging
        print("❌ Error displayed to user: \(appError.title)")
        print("   Message: \(appError.message)")
        if let underlyingError = appError.underlyingError {
            print("   Underlying error: \(underlyingError)")
        }
    }
    
    /// Show a custom error message
    func showError(title: String, message: String) {
        currentError = AppError(title: title, message: message, underlyingError: nil)
        showError = true
        
        print("❌ Error displayed to user: \(title)")
        print("   Message: \(message)")
    }
    
    /// Dismiss the current error
    func dismissError() {
        currentError = nil
        showError = false
    }
    
    /// Handle errors from async operations
    func handleError(_ error: Error, title: String? = nil) {
        showError(error, title: title)
    }
}

/// App-specific error structure
struct AppError: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let underlyingError: String?
    
    static func from(_ error: Error, title: String? = nil) -> AppError {
        let errorTitle = title ?? "Error"
        let errorMessage: String
        let underlyingError: String?
        
        // Parse different error types
        if let localizedError = error as? LocalizedError {
            errorMessage = localizedError.errorDescription ?? error.localizedDescription
            underlyingError = localizedError.failureReason
        } else {
            errorMessage = parseErrorMessage(error)
            underlyingError = String(describing: error)
        }
        
        return AppError(
            title: errorTitle,
            message: errorMessage,
            underlyingError: underlyingError
        )
    }
    
    /// Parse error message to be user-friendly
    private static func parseErrorMessage(_ error: Error) -> String {
        let errorString = error.localizedDescription
        let fullErrorString = String(describing: error).lowercased()
        
        // Network errors
        if errorString.contains("network") || errorString.contains("connection") {
            return "Unable to connect. Please check your internet connection and try again."
        }
        
        // Authentication errors
        if errorString.contains("authentication") || errorString.contains("unauthorized") || errorString.contains("401") {
            return "Authentication failed. Please sign in again."
        }
        
        // Permission errors
        if errorString.contains("permission") || errorString.contains("denied") || errorString.contains("403") {
            return "Permission denied. Please check your account settings."
        }
        
        // Not found errors
        if errorString.contains("not found") || errorString.contains("404") {
            return "The requested resource was not found."
        }
        
        // Server errors
        if errorString.contains("server") || errorString.contains("500") || errorString.contains("502") || errorString.contains("503") {
            return "Server error. Please try again later."
        }
        
        // Supabase/PostgREST errors
        if fullErrorString.contains("postgrest") || fullErrorString.contains("row-level security") || fullErrorString.contains("rls") {
            return "Database access error. Please try again or contact support."
        }
        
        // OAuth errors
        if errorString.contains("oauth") || errorString.contains("invalid callback") {
            return "Connection failed. Please try again."
        }
        
        // Token errors
        if errorString.contains("token") || errorString.contains("expired") || errorString.contains("jwt") {
            return "Session expired. Please sign in again."
        }
        
        // Default: return localized description or a generic message
        if !errorString.isEmpty && errorString != "The operation couldn't be completed." {
            return errorString
        }
        
        return "An unexpected error occurred. Please try again."
    }
}

/// View modifier to display errors globally
struct ErrorDisplayModifier: ViewModifier {
    @StateObject private var errorManager = ErrorManager.shared
    
    func body(content: Content) -> some View {
        content
            .overlay(
                // Error toast/banner
                VStack {
                    if errorManager.showError, let error = errorManager.currentError {
                        HYKAErrorToast(error: error) {
                            errorManager.dismissError()
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(1000)
                    }
                    Spacer()
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: errorManager.showError)
            )
    }
}

extension View {
    /// Apply error display modifier to any view
    func withErrorDisplay() -> some View {
        self.modifier(ErrorDisplayModifier())
    }
}

/// Error toast component
struct HYKAErrorToast: View {
    let error: AppError
    let onDismiss: () -> Void
    
    @State private var dismissTimer: Timer?
    
    var body: some View {
        HStack(alignment: .top, spacing: HYKATheme.spacingM) {
            // Error icon
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 20))
                .foregroundColor(HYKATheme.Light.destructive)
            
            // Error content
            VStack(alignment: .leading, spacing: 4) {
                Text(error.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(HYKATheme.Light.foreground)
                
                Text(error.message)
                    .font(.system(size: 13))
                    .foregroundColor(HYKATheme.Light.mutedForeground)
                    .lineLimit(3)
            }
            
            Spacer()
            
            // Dismiss button
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(HYKATheme.Light.mutedForeground)
            }
        }
        .padding(HYKATheme.spacingM)
        .background(HYKATheme.Light.card)
        .cornerRadius(HYKATheme.cornerRadiusL)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        .padding(.horizontal, HYKATheme.spacingXXL)
        .padding(.top, HYKATheme.spacingL)
        .onAppear {
            // Auto-dismiss after 5 seconds
            dismissTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
                onDismiss()
            }
        }
        .onDisappear {
            dismissTimer?.invalidate()
        }
    }
}

