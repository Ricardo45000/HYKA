import SwiftUI

struct OnboardingStepSignUpView: View {
    let onNext: () -> Void
    let onSkip: () -> Void
    
    @EnvironmentObject var session: SessionManager
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var showSignUpModal = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: HYKATheme.spacingS) {
                    Text("Welcome Back")
                        .font(HYKATheme.h2)
                        .foregroundColor(HYKATheme.Light.foreground)
                    
                    Text("Sign in to your account")
                        .font(HYKATheme.body)
                        .foregroundColor(HYKATheme.Light.mutedForeground)
                }
                .padding(.horizontal, HYKATheme.spacingXXL)
                .padding(.top, HYKATheme.spacingXXL)
                .padding(.bottom, HYKATheme.spacingL)
                
                VStack(spacing: HYKATheme.spacingL) {
                    // Email field
                    VStack(alignment: .leading, spacing: HYKATheme.spacingS) {
                        Text("Email")
                            .font(HYKATheme.label)
                            .foregroundColor(HYKATheme.Light.foreground)
                        
                        TextField("your.email@example.com", text: $email)
                            .font(HYKATheme.input)
                            .foregroundColor(.black) // Typed text in black
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .padding(.horizontal, HYKATheme.spacingM)
                            .padding(.vertical, HYKATheme.spacingM)
                            .frame(height: 48)
                            .background(HYKATheme.Light.inputBackground)
                            .cornerRadius(HYKATheme.radiusMD)
                            .overlay(
                                RoundedRectangle(cornerRadius: HYKATheme.radiusMD)
                                    .stroke(HYKATheme.Light.border, lineWidth: 1)
                            )
                    }
                    
                    // Password field
                    VStack(alignment: .leading, spacing: HYKATheme.spacingS) {
                        Text("Password")
                            .font(HYKATheme.label)
                            .foregroundColor(HYKATheme.Light.foreground)
                        
                        SecureField("Create a password", text: $password)
                            .font(HYKATheme.input)
                            .foregroundColor(.black) // Typed text in black
                            .padding(.horizontal, HYKATheme.spacingM)
                            .padding(.vertical, HYKATheme.spacingM)
                            .frame(height: 48)
                            .background(HYKATheme.Light.inputBackground)
                            .cornerRadius(HYKATheme.radiusMD)
                            .overlay(
                                RoundedRectangle(cornerRadius: HYKATheme.radiusMD)
                                    .stroke(HYKATheme.Light.border, lineWidth: 1)
                            )
                        
                    }
                    
                    
                    // Sign In button
                    Button {
                        Task {
                            await handleSignIn()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                            Text(isLoading ? "Signing in..." : "Sign In")
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
                                // Google icon SVG path
                                Image(systemName: "globe")
                                    .font(.system(size: 17))
                                    .foregroundColor(HYKATheme.Light.foreground)
                                
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
                                // Facebook icon
                                Image(systemName: "f.circle.fill")
                                    .font(.system(size: 17))
                                    .foregroundColor(.blue)
                                
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
        .scrollDismissesKeyboard(.interactively)
        .background(HYKATheme.Light.background)
        .sheet(isPresented: $showSignUpModal) {
            SignUpModal(
                onSuccess: {
                    showSignUpModal = false
                    onNext()
                },
                onUserExists: {
                    showSignUpModal = false
                    // Show error message
                    ErrorManager.shared.showError(title: "Account Exists", message: "You already have an account. Please sign in instead.")
                }
            )
        }
        .onChange(of: session.isAuthenticated) { oldValue, newValue in
            print("🔍 OnboardingStepSignUpView: Authentication state changed - old: \(oldValue), new: \(newValue)")
            // If user becomes authenticated, proceed to next step
            if newValue {
                print("✅ OnboardingStepSignUpView: User authenticated, calling onNext")
                onNext()
            }
        }
        .withErrorDisplay()
    }
    
    // MARK: - Functions
    
    private func handleSignIn() async {
        isLoading = true
        
        do {
            try await session.signIn(email: email, password: password)
            // Success - session manager will set isAuthenticated to true
            // ContentView will automatically route based on onboarding status:
            // - First-time users → OnboardingFlowView
            // - Returning users → Main tabs
            print("✅ Sign in successful - ContentView will handle routing")
        } catch {
            // Show error using ErrorManager
            let userMessage = parseError(error)
            ErrorManager.shared.showError(title: "Sign In Failed", message: userMessage)
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
        } else if errorString.contains("Invalid email") {
            return "Please enter a valid email address."
        } else if errorString.contains("network") || errorString.contains("connection") {
            return "Network error. Please check your connection and try again."
        } else {
            return "An error occurred. Please try again."
        }
    }
    
    private func handleGoogleSignIn() async {
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
    
    private func handleFacebookSignIn() async {
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
    OnboardingStepSignUpView(onNext: {}, onSkip: {})
        .environmentObject(SessionManager())
}
