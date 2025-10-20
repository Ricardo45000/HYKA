import SwiftUI

struct AuthView: View {
    @EnvironmentObject var session: SessionManager
    @Environment(\.dismiss) var dismiss
    @Environment(\.presentationMode) var presentationMode
    
    var initialEmail: String? = nil
    var initialMessage: String? = nil
    
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showSignUpModal = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: HYKATheme.spacingXXL) {
                    // HYKA title
                    Text("HYKA")
                        .font(.system(size: 51, weight: .black, design: .default))
                        .fontWidth(.condensed)
                        .modifier(ForwardSlant(degrees: 10))
                        .kerning(1)
                        .foregroundColor(HYKATheme.Light.foreground)
                        .padding(.top, HYKATheme.spacingXXL)
                    
                    // Welcome section - centered
                    VStack(spacing: HYKATheme.spacingS) {
                        Text("Welcome")
                            .font(HYKATheme.h2)
                            .foregroundColor(HYKATheme.Light.foreground)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                        
                        Text("Log in to your account")
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
                                placeholder: "Enter your password",
                                text: $password,
                                isSecure: true,
                                textContentType: .password
                            )
                        }
                        
                        // Info message (when user already exists)
                        if let initialMessage = initialMessage {
                            HYKAUIAlert(
                                title: "Account Exists",
                                description: initialMessage,
                                variant: .default,
                                icon: "info.circle"
                            )
                        }
                        
                        // Error message
                        if showError, let errorMessage = errorMessage {
                            HYKAUIAlert(
                                title: "Login Failed",
                                description: errorMessage,
                                variant: .destructive,
                                icon: "exclamationmark.triangle"
                            )
                        }
                        
                        // Log in button
                        Button {
                            Task {
                                await handleLogin()
                            }
                        } label: {
                            HStack(spacing: 8) {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                }
                                Text(isLoading ? "Logging in..." : "Log In")
                                    .font(HYKATheme.button)
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color.hykaPurple)
                            .cornerRadius(HYKATheme.cornerRadiusM)
                        }
                        .disabled(email.isEmpty || password.isEmpty || isLoading)
                        .opacity((email.isEmpty || password.isEmpty || isLoading) ? 0.5 : 1.0)
                        
                        // Show loading state while waiting for OAuth callback
                        if isLoading && !session.isAuthenticated {
                            VStack(spacing: 12) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: Color.hykaPurple))
                                    .scaleEffect(1.2)
                                
                                Text("Waiting for authentication...")
                                    .font(HYKATheme.footnote)
                                    .foregroundColor(HYKATheme.Light.mutedForeground)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.top, HYKATheme.spacingL)
                        }
                        
                        // Show success message when authenticated
                        if session.isAuthenticated && !isLoading {
                            VStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 48))
                                    .foregroundColor(.green)
                                
                                Text("Authentication successful!")
                                    .font(HYKATheme.h3)
                                    .foregroundColor(HYKATheme.Light.foreground)
                                
                                Text("You can close this window")
                                    .font(HYKATheme.footnote)
                                    .foregroundColor(HYKATheme.Light.mutedForeground)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.top, HYKATheme.spacingL)
                        }
                        
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
                                await handleGoogleSignIn()
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
                                await handleFacebookSignIn()
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
                        
                        // Sign up link
                        HStack(spacing: 4) {
                            Text("Don't have an account?")
                                .font(HYKATheme.footnote)
                                .foregroundColor(HYKATheme.Light.mutedForeground)
                            
                            Button {
                                showSignUpModal = true
                            } label: {
                                Text("Sign up")
                                    .font(HYKATheme.footnote)
                                    .fontWeight(.medium)
                                    .foregroundColor(Color.hykaPurple)
                            }
                        }
                        .padding(.top, HYKATheme.spacingL)
                    }
                    .padding(.horizontal, HYKATheme.spacingXXL)
                    .padding(.bottom, HYKATheme.spacingXXL)
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
        .sheet(isPresented: $showSignUpModal) {
            SignUpModal(
                onSuccess: {
                    showSignUpModal = false
                    dismiss()
                },
                onUserExists: {
                    showSignUpModal = false
                    // Show error message that user already has an account
                    errorMessage = "You already have an account. Please sign in instead."
                    showError = true
                }
            )
        }
        .onAppear {
            // Pre-fill email if provided
            if let initialEmail = initialEmail, email.isEmpty {
                email = initialEmail
            }
        }
        .onChange(of: session.isAuthenticated) { oldValue, newValue in
            // Stop loading when user becomes authenticated (after OAuth)
            // DO NOT auto-dismiss - user will close manually
            print("")
            print("═══════════════════════════════════════")
            print("🔔 AuthView: .onChange TRIGGERED")
            print("   session.isAuthenticated changed")
            print("   Old value: \(oldValue)")
            print("   New value: \(newValue)")
            print("   isLoading: \(isLoading)")
            print("═══════════════════════════════════════")
            print("")
            
            if newValue && !oldValue {
                print("✅ AuthView: User authenticated - stopping loading")
                print("ℹ️ Modal will stay open - user will close manually")
                
                // Stop loading but keep modal open
                isLoading = false
            } else {
                print("⚠️ AuthView: Not changing loading state - newValue: \(newValue), oldValue: \(oldValue)")
            }
        }
        .onChange(of: session.hasCompletedOnboarding) { oldValue, newValue in
            print("🔍 AuthView: Onboarding state changed - old: \(oldValue), new: \(newValue)")
        }
        .onOpenURL { url in
            print("")
            print("🔵🔵🔵 AuthView.onOpenURL FIRED (Modal Handler) 🔵🔵🔵")
            print("   URL: \(url)")
            print("   This handler fires when deep link arrives while modal is open")
            print("")
            
            // Forward to main app handler
            // We need to access the session's handleOAuthCallback
            if url.scheme == "com.hyka.app" && url.absoluteString.lowercased().contains("callback") {
                print("✅ AuthView detected OAuth callback, forwarding to SessionManager")
                Task { @MainActor in
                    await session.handleOAuthCallback(url: url)
                }
            }
        }
    }
    
    // MARK: - Functions
    
    private func handleLogin() async {
        showError = false
        errorMessage = nil
        isLoading = true
        
        do {
            try await session.signIn(email: email, password: password)
            // Success - dismiss the login view
            dismiss()
        } catch {
            // Show error message
            errorMessage = parseError(error)
            showError = true
            ErrorManager.shared.showError(error, title: "Sign In Failed")
        }
        
        isLoading = false
    }
    
    private func parseError(_ error: Error) -> String {
        let errorString = error.localizedDescription
        
        // Common Supabase errors
        if errorString.contains("Invalid login credentials") || errorString.contains("invalid") {
            return "Invalid email or password. Please try again."
        } else if errorString.contains("Email not confirmed") {
            return "Please confirm your email before logging in."
        } else if errorString.contains("network") || errorString.contains("connection") {
            return "Network error. Please check your connection and try again."
        } else {
            return "An error occurred. Please try again."
        }
    }
    
    private func handleGoogleSignIn() async {
        isLoading = true
        showError = false
        
        do {
            try await session.signInWithGoogle()
            // OAuth flow initiated - user will be redirected to Google
            // Callback will be handled in MainApp via deep link
            // DO NOT dismiss modal yet - wait for deep link callback
            print("🔄 Google OAuth flow initiated...")
            print("⏳ Keeping modal open to receive deep link callback...")
            // Keep isLoading true - this keeps modal open and shows loading state
            // Modal will dismiss when isAuthenticated changes to true (via onChange handler)
        } catch {
            errorMessage = "Failed to initiate Google sign in. Please try again."
            showError = true
            isLoading = false // Only set to false on error
            ErrorManager.shared.showError(error, title: "Google Sign In Failed")
        }
        
        // DO NOT set isLoading = false here - keep it true to prevent modal dismissal
        // It will be set to false when OAuth completes or errors
    }
    
    private func handleFacebookSignIn() async {
        isLoading = true
        showError = false
        
        do {
            try await session.signInWithFacebook()
            // OAuth flow initiated - user will be redirected to Facebook
            // Callback will be handled in MainApp via deep link
            // DO NOT dismiss modal yet - wait for deep link callback
            print("🔄 Facebook OAuth flow initiated...")
            print("⏳ Keeping modal open to receive deep link callback...")
            // Keep isLoading true - this keeps modal open and shows loading state
            // Modal will dismiss when isAuthenticated changes to true (via onChange handler)
        } catch {
            errorMessage = "Failed to initiate Facebook sign in. Please try again."
            showError = true
            isLoading = false // Only set to false on error
            ErrorManager.shared.showError(error, title: "Facebook Sign In Failed")
        }
        
        // DO NOT set isLoading = false here - keep it true to prevent modal dismissal
        // It will be set to false when OAuth completes or errors
    }
}

#Preview {
    AuthView()
        .environmentObject(SessionManager())
}
