import SwiftUI
import Auth

struct SignUpModal: View {
    let onSuccess: () -> Void
    var onUserExists: (() -> Void)? = nil
    
    @EnvironmentObject var session: SessionManager
    @Environment(\.dismiss) var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var showSignInModal = false
    @State private var signInEmail: String = ""
    @State private var showUserExistsMessage = false

    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: HYKATheme.spacingXXL) {
                        // HYKA logo
                        Image("Logo-transparent-black")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 120)
                            .padding(.top, max(0, HYKATheme.spacingXXL - geometry.size.height * 0.05))
                    
                    // Create an Account section - centered
                    VStack(spacing: HYKATheme.spacingS) {
                        Text("Create an Account")
                            .font(HYKATheme.h2)
                            .foregroundColor(HYKATheme.Light.foreground)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                        
                        Text("Join the ultra running community")
                            .font(HYKATheme.body)
                            .foregroundColor(HYKATheme.Light.mutedForeground)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, HYKATheme.spacingXXL)
                    .padding(.top, HYKATheme.spacingL)
                    
                    VStack(spacing: HYKATheme.spacingL) {
                        // Email field
                        VStack(alignment: .leading, spacing: HYKATheme.spacingS) {
                            HYKAUILabel(text: "Email", isRequired: true)
                            HYKAUIInput(
                                placeholder: "your.email@example.com",
                                text: $email,
                                keyboardType: .emailAddress,
                                textContentType: .emailAddress
                            )
                        }
                        
                        // Password field
                        VStack(alignment: .leading, spacing: HYKATheme.spacingS) {
                            HYKAUILabel(text: "Password", isRequired: true)
                            HYKAUIInput(
                                placeholder: "Create a password",
                                text: $password,
                                isSecure: true,
                                textContentType: .newPassword
                            )
                            
                            Text("Must be at least 8 characters")
                                .font(HYKATheme.footnote)
                                .foregroundColor(HYKATheme.Light.mutedForeground)
                        }
                        
                        // Error message
                        
                        // Sign Up button
                        Button {
                            Task {
                                await handleSignUp()
                            }
                        } label: {
                            HStack(spacing: 8) {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                }
                                Text(isLoading ? "Creating account..." : "Sign Up")
                                    .font(HYKATheme.button)
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color.hykaPurple)
                            .cornerRadius(HYKATheme.cornerRadiusM)
                        }
                        .disabled(email.isEmpty || password.count < 8 || isLoading)
                        .opacity((email.isEmpty || password.count < 8 || isLoading) ? 0.5 : 1.0)
                        
                        // Separator
                        HStack {
                            Rectangle()
                                .fill(HYKATheme.Light.border)
                                .frame(height: 1)
                            
                            Text("or continue with")
                                .font(HYKATheme.footnote)
                                .foregroundColor(HYKATheme.Light.mutedForeground)
                                .padding(.horizontal, HYKATheme.spacingL)
                                .background(HYKATheme.Light.background)
                            
                            Rectangle()
                                .fill(HYKATheme.Light.border)
                                .frame(height: 1)
                        }
                        .padding(.vertical, HYKATheme.spacingL)
                        
                        // Social login buttons
                        VStack(spacing: HYKATheme.spacingM) {
                            Button {
                                Task {
                                    await handleGoogleSignUp()
                                }
                            } label: {
                                HStack {
                                    GoogleLogo(size: 20)
                                    
                                    Text("Continue with Google")
                                        .font(HYKATheme.button)
                                        .foregroundColor(HYKATheme.Light.foreground)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(Color.clear)
                                .cornerRadius(HYKATheme.cornerRadiusM)
                                .overlay(
                                    RoundedRectangle(cornerRadius: HYKATheme.cornerRadiusM)
                                        .stroke(HYKATheme.Light.border, lineWidth: 1)
                                )
                            }
                            .disabled(isLoading)
                            
                            Button {
                                Task {
                                    await handleFacebookSignUp()
                                }
                            } label: {
                                HStack {
                                    FacebookLogo(size: 20)
                                    
                                    Text("Continue with Facebook")
                                        .font(HYKATheme.button)
                                        .foregroundColor(HYKATheme.Light.foreground)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(Color.clear)
                                .cornerRadius(HYKATheme.cornerRadiusM)
                                .overlay(
                                    RoundedRectangle(cornerRadius: HYKATheme.cornerRadiusM)
                                        .stroke(HYKATheme.Light.border, lineWidth: 1)
                                )
                            }
                            .disabled(isLoading)
                        }
                        
                        Text("By signing up, you agree to our Terms of Service and Privacy Policy")
                            .font(HYKATheme.footnote)
                            .foregroundColor(HYKATheme.Light.mutedForeground)
                            .multilineTextAlignment(.center)
                            .padding(.top, HYKATheme.spacingL)
                        
                        // Sign in link
                        HStack(spacing: 4) {
                            Text("You already have an account?")
                                .font(HYKATheme.footnote)
                                .foregroundColor(HYKATheme.Light.mutedForeground)
                            
                            Button {
                                showSignInModal = true
                            } label: {
                                Text("Sign in")
                                    .font(HYKATheme.footnote)
                                    .fontWeight(.medium)
                                    .foregroundColor(Color.hykaPurple)
                            }
                        }
                        .padding(.top, HYKATheme.spacingM)
                    }
                    .padding(.horizontal, HYKATheme.spacingXXL)
                    .padding(.bottom, HYKATheme.spacingXXL)
                    }
                }
            }
            .background(HYKATheme.Light.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Color.hykaPurple)
                }
            }
        }
        .sheet(isPresented: $showSignInModal) {
            AuthView(
                initialEmail: showUserExistsMessage ? signInEmail : nil,
                initialMessage: showUserExistsMessage ? "You already have an account. Please sign in." : nil
            )
            .environmentObject(session)
            .interactiveDismissDisabled(false)
        }
        .onChange(of: session.isAuthenticated) { oldValue, newValue in
            // Auto-dismiss when user becomes authenticated (after OAuth)
            print("🔍 SignUpModal: Authentication state changed - old: \(oldValue), new: \(newValue)")
            if newValue {
                print("✅ SignUpModal: User authenticated, calling onSuccess")
                showSignInModal = false // Close Sign In modal if open
                onSuccess()
            }
        }
        .withErrorDisplay()
    }
    
    // MARK: - Functions
    
    private func handleSignUp() async {
        isLoading = true
        
        do {
            try await session.signUp(email: email, password: password)
            // Success - dismiss modal and let ContentView handle routing
            // ContentView will show OnboardingFlowView for first-time users
            onSuccess()
        } catch {
            let errorString = error.localizedDescription
            let fullErrorString = String(describing: error).lowercased()
            
            // Check if user already exists - check multiple error formats
            let userExistsPatterns = [
                "user already registered",
                "already registered",
                "already exists",
                "user already exists",
                "email already registered",
                "email already exists",
                "duplicate key value",
                "unique constraint"
            ]
            
            let userExists = userExistsPatterns.contains { pattern in
                errorString.lowercased().contains(pattern) || 
                fullErrorString.contains(pattern)
            }
            
            if userExists {
                // User already exists - show message and open Sign In modal
                print("⚠️ User already exists, showing message and opening Sign In modal")
                isLoading = false
                signInEmail = email // Pre-fill email in sign in form
                showUserExistsMessage = true
                showSignInModal = true
                // Call onUserExists callback if provided
                onUserExists?()
            } else {
                // Show error using ErrorManager
                let userMessage = parseError(error)
                ErrorManager.shared.showError(title: "Sign Up Failed", message: userMessage)
            }
        }
        
        isLoading = false
    }
    
    private func parseError(_ error: Error) -> String {
        let errorString = error.localizedDescription.lowercased()
        let fullErrorString = String(describing: error).lowercased()
        
        print("🔍 Parsing sign up error: \(error)")
        print("🔍 Error description: \(errorString)")
        print("🔍 Full error string: \(fullErrorString)")
        
        // Check for NSError with userInfo
        let nsError = error as NSError
        print("🔍 NSError detected - code: \(nsError.code), domain: \(nsError.domain)")
        
        // Check userInfo for more details
        let userInfo = nsError.userInfo
        print("🔍 NSError userInfo: \(userInfo)")
        
        // Check for error message in userInfo
        if let message = userInfo["message"] as? String {
            print("🔍 Found message in userInfo: \(message)")
            return formatErrorMessage(message)
        }
        
        // Check for error description
        if let description = userInfo[NSLocalizedDescriptionKey] as? String,
           description != errorString {
            print("🔍 Found description in userInfo: \(description)")
            let parsed = parseErrorString(description)
            if parsed != description.lowercased() {
                return parsed
            }
        }
        
        // Parse error string for common patterns
        return parseErrorString(errorString)
    }
    
    private func parseErrorString(_ errorString: String) -> String {
        let lowercased = errorString.lowercased()
        
        // User already exists
        if lowercased.contains("user already registered") || 
           lowercased.contains("already registered") ||
           lowercased.contains("already exists") ||
           lowercased.contains("user already exists") {
            return "This email is already registered. Please log in instead."
        }
        
        // Password validation
        if lowercased.contains("password should be at least") ||
           lowercased.contains("password must be at least") ||
           (lowercased.contains("password") && lowercased.contains("8")) ||
           lowercased.contains("password") && lowercased.contains("minimum") {
            return "Password must be at least 8 characters long."
        }
        
        // Email format validation
        if lowercased.contains("invalid email") ||
           lowercased.contains("email format") ||
           lowercased.contains("email is not valid") ||
           lowercased.contains("email address is invalid") ||
           lowercased.contains("invalid email format") ||
           lowercased.contains("email format is not valid") ||
           lowercased.contains("email") && (lowercased.contains("invalid") || lowercased.contains("malformed")) {
            return "Please enter a valid email address."
        }
        
        // Required fields
        if lowercased.contains("email") && lowercased.contains("required") {
            return "Email is required."
        }
        if lowercased.contains("password") && lowercased.contains("required") {
            return "Password is required."
        }
        
        // Network errors
        if lowercased.contains("network") || 
           lowercased.contains("connection") ||
           lowercased.contains("timed out") ||
           lowercased.contains("timeout") {
            return "Network error. Please check your connection and try again."
        }
        
        // Weak password
        if lowercased.contains("weak password") ||
           lowercased.contains("password too weak") ||
           lowercased.contains("password strength") {
            return "Password is too weak. Please use a stronger password."
        }
        
        // Format and return the original error message
        let formattedMessage = formatErrorMessage(errorString)
        return formattedMessage.isEmpty ? "An error occurred. Please try again." : formattedMessage
    }
    
    private func formatErrorMessage(_ message: String) -> String {
        // Capitalize first letter and clean up common patterns
        var formatted = message.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove common prefixes
        if formatted.lowercased().hasPrefix("error: ") {
            formatted = String(formatted.dropFirst(7))
        }
        if formatted.lowercased().hasPrefix("auth: ") {
            formatted = String(formatted.dropFirst(6))
        }
        if formatted.lowercased().hasPrefix("signup failed: ") {
            formatted = String(formatted.dropFirst(15))
        }
        
        // Capitalize first letter
        if !formatted.isEmpty {
            formatted = formatted.prefix(1).uppercased() + formatted.dropFirst()
        }
        
        return formatted
    }
    
    private func handleGoogleSignUp() async {
        isLoading = true
        
        do {
            try await session.signInWithGoogle()
            // OAuth flow initiated - user will be redirected to Google
            // Callback will be handled in MainApp via deep link
            print("🔄 Google OAuth flow initiated...")
        } catch {
            ErrorManager.shared.showError(error, title: "Google Sign In Failed")
        }
        
        isLoading = false
    }
    
    private func handleFacebookSignUp() async {
        isLoading = true
        
        do {
            try await session.signInWithFacebook()
            // OAuth flow initiated - user will be redirected to Facebook
            // Callback will be handled in MainApp via deep link
            print("🔄 Facebook OAuth flow initiated...")
        } catch {
            ErrorManager.shared.showError(error, title: "Facebook Sign In Failed")
        }
        
        isLoading = false
    }
}

#Preview {
    SignUpModal(onSuccess: {})
        .environmentObject(SessionManager())
}

