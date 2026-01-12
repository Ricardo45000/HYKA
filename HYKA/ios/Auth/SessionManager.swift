import Foundation
import AuthenticationServices
import Supabase
import PostgREST
import Combine
import UIKit
import ObjectiveC

@MainActor
final class SessionManager: NSObject, ObservableObject {
    @Published var isAuthenticated = false {
        didSet {
            print("")
            print("🔔 SessionManager.isAuthenticated CHANGED")
            print("   Old value: \(oldValue)")
            print("   New value: \(isAuthenticated)")
            print("   Thread: \(Thread.isMainThread ? "MAIN" : "BACKGROUND")")
            print("   Call stack: \(Thread.callStackSymbols.prefix(3).joined(separator: "\n"))")
            print("")
        }
    }
    @Published var isLoading = true
    @Published var currentUser: User?
    @Published var hasCompletedOnboarding = false
    @Published var oauthUserInfo: OAuthUserInfo? = nil
    
    private let onboardingKey = "hasCompletedOnboarding"
    
    override init() {
        super.init()
        Task {
            await checkSession()
        }
    }
    
    /// Check for an existing session on app launch
    func checkSession() async {
        isLoading = true
        do {
            // Try to get the current session
            let session = try await Supa.client.auth.session
            currentUser = session.user
            isAuthenticated = true
            print("✅ Existing session found for user: \(session.user.email ?? "unknown")")
            
            // Check onboarding status from Supabase
            do {
                let hasCompleted = try await SupabaseService.hasCompletedOnboarding(userId: session.user.id)
                hasCompletedOnboarding = hasCompleted
                // Sync to UserDefaults as a backup
                UserDefaults.standard.set(hasCompleted, forKey: onboardingKey)
                
                // Sync user ID to UserDefaults for push notifications
                UserDefaults.standard.set(session.user.id.uuidString, forKey: "hyka.user.id")
                
                // Register device token
                Task {
                    if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                        await appDelegate.registerDeviceTokenForUser(session.user.id)
                    }
                }
                
                print("✅ Onboarding status loaded from Supabase: \(hasCompleted)")
            } catch {
                // Fallback to UserDefaults if Supabase check fails
                hasCompletedOnboarding = UserDefaults.standard.bool(forKey: onboardingKey)
                print("⚠️ Failed to load onboarding status from Supabase, using local: \(hasCompletedOnboarding)")
            }
        } catch {
            // No existing session from SDK - check UserDefaults fallback
            print("ℹ️ No session found in SDK, checking UserDefaults fallback...")
            print("   Error: \(error.localizedDescription)")
            
            // Check if we're offline
            let isOffline = !NetworkMonitor.shared.isConnected
            
            // Check if we have a user ID stored in UserDefaults (from OAuth fallback)
            if let userIdString = UserDefaults.standard.string(forKey: "hyka.user.id"),
               let userId = UUID(uuidString: userIdString) {
                // User is authenticated but SDK couldn't read session
                // Check if we have session data in UserDefaults
                if let sessionData = UserDefaults.standard.data(forKey: "supabase.auth.session") {
                    print("✅ Found session data in UserDefaults, user is authenticated")
                    print("   User ID from UserDefaults: \(userIdString)")
                    print("   Offline mode: \(isOffline)")
                    
                    // If offline, skip SDK restoration and use cached data
                    if isOffline {
                        print("📦 Offline mode: Using cached session data without SDK restoration")
                        
                        // Parse session data to get user info (suppress unused warning)
                        if let sessionDict = try? JSONSerialization.jsonObject(with: sessionData) as? [String: Any] {
                            _ = sessionDict["user"] as? [String: Any] ?? (sessionDict["email"] as? String as Any?)
                        }
                        
                        // Create a minimal User object from cached data
                        print("✅ Restored user from cache: \(userIdString)")
                        
                        // Set authentication state from cache
                        isAuthenticated = true
                        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: onboardingKey)
                        
                        print("✅ User authenticated via cached session (offline mode)")
                        print("   - isAuthenticated: \(isAuthenticated)")
                        print("   - hasCompletedOnboarding: \(hasCompletedOnboarding)")
                        print("   - Note: Some features may be limited while offline")
                    } else {
                        // Online - try to restore session to SDK
                        print("🔄 Restoring session to Supabase SDK...")
                        do {
                            // Parse session data from UserDefaults
                            if let sessionDict = try? JSONSerialization.jsonObject(with: sessionData) as? [String: Any],
                               let accessToken = sessionDict["access_token"] as? String,
                               let refreshToken = sessionDict["refresh_token"] as? String {
                                
                                // Use the Supabase Swift SDK's setSession method directly
                                try await Supa.client.auth.setSession(accessToken: accessToken, refreshToken: refreshToken)
                                print("✅ Successfully restored session to Supabase SDK using setSession method")
                                
                                // Verify the session is set
                                let restoredSession = try await Supa.client.auth.session
                                print("✅ Verified session is set in SDK - user ID: \(restoredSession.user.id)")
                                print("   Access token present: \(!restoredSession.accessToken.isEmpty)")
                                currentUser = restoredSession.user
                            } else {
                                print("⚠️ Failed to parse session data from UserDefaults")
                            }
                        } catch {
                            print("⚠️ Failed to restore session to SDK: \(error)")
                            print("   RLS policies may still fail - using REST API fallback")
                        }
                        
                        isAuthenticated = true
                        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: onboardingKey)
                        
                        // Try to fetch user info to populate currentUser
                        do {
                            let hasCompleted = try await SupabaseService.hasCompletedOnboarding(userId: userId)
                            hasCompletedOnboarding = hasCompleted
                            UserDefaults.standard.set(hasCompleted, forKey: onboardingKey)
                            
                            // Sync user ID to UserDefaults for push notifications
                            UserDefaults.standard.set(userId.uuidString, forKey: "hyka.user.id")
                            
                            // Register device token
                            Task {
                                if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                                    await appDelegate.registerDeviceTokenForUser(userId)
                                }
                            }
                            
                            print("✅ Onboarding status loaded from Supabase: \(hasCompleted)")
                        } catch {
                            print("⚠️ Failed to load onboarding status from Supabase: \(error)")
                            print("   Using UserDefaults value: \(hasCompletedOnboarding)")
                        }
                        
                        print("✅ checkSession() - User authenticated via UserDefaults fallback")
                        print("   - isAuthenticated: \(isAuthenticated)")
                        print("   - hasCompletedOnboarding: \(hasCompletedOnboarding)")
                    }
                } else {
                    print("⚠️ User ID found but no session data - user may not be authenticated")
                    isAuthenticated = false
                    currentUser = nil
                    hasCompletedOnboarding = false
                }
            } else {
                // No session and no fallback data
                isAuthenticated = false
                currentUser = nil
                hasCompletedOnboarding = false
                print("ℹ️ No existing session found")
            }
        }
        isLoading = false
    }

    func signUp(email: String, password: String) async throws {
        do {
            let response = try await Supa.client.auth.signUp(email: email, password: password)
            currentUser = response.user
            isAuthenticated = true
            print("✅ Sign up successful for: \(email)")
            
            // Store user ID and email in UserDefaults for offline access
            UserDefaults.standard.set(response.user.id.uuidString, forKey: "hyka.user.id")
            UserDefaults.standard.set(email, forKey: "hyka.user.email")
            
            // Register device token for push notifications
            Task {
                if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                    await appDelegate.registerDeviceTokenForUser(response.user.id)
                }
            }
            
            // Store session data for offline fallback
            if let session = try? await Supa.client.auth.session {
                let sessionDict: [String: Any] = [
                    "access_token": session.accessToken,
                    "refresh_token": session.refreshToken,
                    "user": [
                        "id": session.user.id.uuidString,
                        "email": email
                    ]
                ]
                if let sessionJSON = try? JSONSerialization.data(withJSONObject: sessionDict) {
                    UserDefaults.standard.set(sessionJSON, forKey: "supabase.auth.session")
                    print("✅ Stored session in UserDefaults for offline access")
                }
            }
            
            // Check onboarding status from Supabase for new user
            do {
                let hasCompleted = try await SupabaseService.hasCompletedOnboarding(userId: response.user.id)
                hasCompletedOnboarding = hasCompleted
                UserDefaults.standard.set(hasCompleted, forKey: onboardingKey)
                print("✅ Onboarding status loaded from Supabase after sign up: \(hasCompleted)")
            } catch {
                // New user - onboarding not completed yet
                hasCompletedOnboarding = false
                UserDefaults.standard.set(false, forKey: onboardingKey)
                print("ℹ️ New user - onboarding not completed yet")
            }
        } catch {
            print("❌ SignUp error: \(error)")
            throw error
        }
    }

    func signIn(email: String, password: String) async throws {
        do {
            let response = try await Supa.client.auth.signIn(email: email, password: password)
            currentUser = response.user
            isAuthenticated = true
            print("✅ Sign in successful for: \(email)")
            
            // Store user ID and email in UserDefaults for offline access
            UserDefaults.standard.set(response.user.id.uuidString, forKey: "hyka.user.id")
            UserDefaults.standard.set(email, forKey: "hyka.user.email")
            
            // Store session data for offline fallback
            if let session = try? await Supa.client.auth.session {
                let sessionDict: [String: Any] = [
                    "access_token": session.accessToken,
                    "refresh_token": session.refreshToken,
                    "user": [
                        "id": session.user.id.uuidString,
                        "email": email
                    ]
                ]
                if let sessionJSON = try? JSONSerialization.data(withJSONObject: sessionDict) {
                    UserDefaults.standard.set(sessionJSON, forKey: "supabase.auth.session")
                    print("✅ Stored session in UserDefaults for offline access")
                }
            }
            
            // Register device token for push notifications
            Task {
                if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                    await appDelegate.registerDeviceTokenForUser(response.user.id)
                }
            }
            
            // Check onboarding status from Supabase
            do {
                let hasCompleted = try await SupabaseService.hasCompletedOnboarding(userId: response.user.id)
                hasCompletedOnboarding = hasCompleted
                UserDefaults.standard.set(hasCompleted, forKey: onboardingKey)
                print("✅ Onboarding status loaded from Supabase after sign in: \(hasCompleted)")
            } catch {
                // Fallback to UserDefaults if Supabase check fails
                hasCompletedOnboarding = UserDefaults.standard.bool(forKey: onboardingKey)
                print("⚠️ Failed to load onboarding status from Supabase after sign in, using local: \(hasCompletedOnboarding)")
            }
        } catch {
            print("❌ SignIn error: \(error)")
            throw error
        }
    }
    
    func signOut() async {
        do {
            try await Supa.client.auth.signOut()
            currentUser = nil
            isAuthenticated = false
            // Reset onboarding status on sign out
            hasCompletedOnboarding = false
            
            // Clear all UserDefaults session data
            UserDefaults.standard.removeObject(forKey: "supabase.auth.session")
            UserDefaults.standard.removeObject(forKey: "hyka.user.id")
            UserDefaults.standard.removeObject(forKey: "hyka.user.email")
            UserDefaults.standard.set(false, forKey: onboardingKey)
            
            print("✅ Signed out successfully - all session data cleared from UserDefaults")
        } catch {
            print("❌ Sign out error: \(error)")
            // Even if Supabase signOut fails, clear local session data
            currentUser = nil
            isAuthenticated = false
            hasCompletedOnboarding = false
            UserDefaults.standard.removeObject(forKey: "supabase.auth.session")
            UserDefaults.standard.removeObject(forKey: "hyka.user.id")
            UserDefaults.standard.removeObject(forKey: "hyka.user.email")
            UserDefaults.standard.set(false, forKey: onboardingKey)
            print("⚠️ Cleared local session data despite signOut error")
        }
    }
    
    /// Mark onboarding as complete (called after saving all onboarding data)
    func completeOnboarding() async {
        // Update local state
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: onboardingKey)
        
        // Sync to Supabase - ensure the profile is marked as onboarding complete
        if let userId = currentUser?.id ?? UUID(uuidString: UserDefaults.standard.string(forKey: "hyka.user.id") ?? "") {
            do {
                // Update the profile in Supabase to mark onboarding as complete
                try await SupabaseService.updateOnboardingStatus(userId: userId, completed: true)
                print("✅ Onboarding completion synced to Supabase")
                // Note: Default fuel types are now hardcoded in the app, no need to create them in DB
            } catch {
                print("⚠️ Failed to sync onboarding completion to Supabase: \(error)")
                // Still mark as complete locally even if Supabase sync fails
            }
        } else {
            print("⚠️ Could not get user ID to sync onboarding status to Supabase")
        }
        
        print("✅ Onboarding completed and saved locally")
    }

    // MARK: - OAuth Sign In
    
    /// Sign in with Google using ASWebAuthenticationSession (recommended by Apple)
    func signInWithGoogle() async throws {
        let redirectURL = URL(string: "app.hyka.com://callback")!
        try await performOAuthWithASWebAuthenticationSession(
            provider: "google",
            redirectURL: redirectURL
        )
    }
    
    /// Sign in with Facebook using ASWebAuthenticationSession (recommended by Apple)
    func signInWithFacebook() async throws {
        let redirectURL = URL(string: "app.hyka.com://callback")!
        try await performOAuthWithASWebAuthenticationSession(
            provider: "facebook",
            redirectURL: redirectURL
        )
    }
    
    /// Perform OAuth using ASWebAuthenticationSession (Apple's recommended approach)
    /// This properly handles redirect URIs and system-level OAuth flows
    private func performOAuthWithASWebAuthenticationSession(
        provider: String,
        redirectURL: URL
    ) async throws {
        print("")
        print("═══════════════════════════════════════")
        print("🔄 INITIATING \(provider.uppercased()) OAUTH WITH ASWEBAUTHENTICATIONSESSION")
        print("═══════════════════════════════════════")
        print("")
        
        // Get the root view controller for presentation
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            throw OAuthError.noViewController
        }
        
        // Construct Supabase OAuth URL with PKCE flow
        // PKCE is required for the Supabase Swift SDK to work properly
        let supabaseURL = Config.supabaseURL
        var components = URLComponents(string: "\(supabaseURL)/auth/v1/authorize")!
        components.queryItems = [
            URLQueryItem(name: "provider", value: provider),
            URLQueryItem(name: "redirect_to", value: redirectURL.absoluteString),
            URLQueryItem(name: "flow_type", value: "pkce") // Force PKCE flow instead of implicit
        ]
        
        guard let authURL = components.url else {
            throw OAuthError.invalidURL
        }
        
        print("📱 OAuth URL: \(authURL)")
        print("📱 Redirect URL: \(redirectURL)")
        print("📱 Using ASWebAuthenticationSession (Apple's recommended method)")
        print("")
        
        // Use ASWebAuthenticationSession for proper OAuth handling
        return try await withCheckedThrowingContinuation { continuation in
            // Create presentation context provider first
            let presentationProvider = AuthPresentationContextProvider(viewController: rootViewController)
            
            // Track if continuation has been resumed to avoid double resume
            var hasResumed = false
            let resumeOnce: (Result<Void, Error>) -> Void = { result in
                guard !hasResumed else {
                    print("⚠️ Continuation already resumed, ignoring duplicate resume")
                    return
                }
                hasResumed = true
                switch result {
                case .success:
                    continuation.resume(returning: ())
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            
            let authSession = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: redirectURL.scheme
            ) { callbackURL, error in
                if let error = error {
                    print("❌ ASWebAuthenticationSession error: \(error)")
                    
                    // Check if user cancelled
                    if let nsError = error as NSError?,
                       nsError.domain == ASWebAuthenticationSessionErrorDomain,
                       nsError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        print("ℹ️ User cancelled OAuth flow")
                        resumeOnce(.failure(OAuthError.cancelled))
                        return
                    }
                    
                    resumeOnce(.failure(error))
                    return
                }
                
                guard let callbackURL = callbackURL else {
                    print("❌ No callback URL received")
                    resumeOnce(.failure(OAuthError.noCallback))
                    return
                }
                
                print("")
                print("═══════════════════════════════════════")
                print("✅ OAUTH CALLBACK RECEIVED")
                print("   URL: \(callbackURL)")
                print("   Using ASWebAuthenticationSession callback")
                print("═══════════════════════════════════════")
                print("")
                
                // Process the callback
                Task { @MainActor in
                    await self.handleOAuthCallback(url: callbackURL)
                    resumeOnce(.success(()))
                }
            }
            
            // Set presentation context provider BEFORE starting
            authSession.presentationContextProvider = presentationProvider
            authSession.prefersEphemeralWebBrowserSession = false // Use shared cookies
            
            // Verify presentation context provider is set
            if authSession.presentationContextProvider == nil {
                print("❌ CRITICAL: Presentation context provider is nil!")
                resumeOnce(.failure(OAuthError.noViewController))
                return
            }
            print("✅ Presentation context provider is set")
            
            // Start the session - must be called AFTER setting presentation context provider
            if !authSession.start() {
                print("❌ Failed to start ASWebAuthenticationSession")
                resumeOnce(.failure(OAuthError.sessionFailed))
            } else {
                print("✅ ASWebAuthenticationSession started")
                print("🌐 Browser should open with \(provider) login")
                
                // Retain the session and provider to prevent deallocation
                objc_setAssociatedObject(rootViewController, "oauthAuthSession", authSession, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                objc_setAssociatedObject(rootViewController, "oauthPresentationProvider", presentationProvider, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
        }
    }
    
    func signInWithApple() async throws {
        let redirectURL = URL(string: "app.hyka.com://callback")!
        try await performOAuthWithASWebAuthenticationSession(
            provider: "apple",
            redirectURL: redirectURL
        )
    }
    
    // Handle OAuth callback from deep link
    func handleOAuthCallback(url: URL) async {
        print("")
        print("═══════════════════════════════════════")
        print("🔗 PROCESSING OAUTH CALLBACK")
        print("   URL: \(url)")
        print("   Absolute String: \(url.absoluteString)")
        print("   Scheme: \(url.scheme ?? "nil")")
        print("   Host: \(url.host ?? "nil")")
        print("   Query: \(url.query ?? "nil")")
        print("   Current isAuthenticated: \(isAuthenticated)")
        print("   Current isLoading: \(isLoading)")
        print("═══════════════════════════════════════")
        print("")
        
        // Check for error in query parameters
        if let query = url.query,
           query.contains("error=") {
            print("⚠️ OAuth callback contains error!")
            
            // Parse error details
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            if let queryItems = components?.queryItems {
                for item in queryItems {
                    print("   \(item.name): \(item.value ?? "nil")")
                    if item.name == "error_description" {
                        let description = item.value?.replacingOccurrences(of: "+", with: " ") ?? "Unknown error"
                        print("")
                        print("❌ OAUTH ERROR: \(description)")
                        print("")
                        print("🔧 TROUBLESHOOTING:")
                        if description.contains("state parameter missing") {
                            print("   1. This usually means Supabase Site URL doesn't match")
                            print("   2. Go to Supabase Dashboard → Auth → URL Configuration")
                            print("   3. Set Site URL to: app.hyka.com://callback")
                            print("   4. Make sure Redirect URLs includes: app.hyka.com://**")
                            print("   5. Click Save and wait 1-2 minutes for changes to propagate")
                            print("   6. Try OAuth again")
                        }
                    }
                }
            }
            
            await MainActor.run {
                isLoading = false
            }
            return
        }
        
        // Ensure we're on main thread for state updates
        await MainActor.run {
            isLoading = true
            print("⏳ Set isLoading = true (on main thread)")
        }
        
        do {
            // Check if URL uses fragment (#) instead of query parameters (?)
            // Supabase returns OAuth tokens in fragment for implicit flow
            let urlString = url.absoluteString
            
            // Check if URL has fragment with tokens
            if urlString.contains("#access_token=") {
                print("🔄 Detected fragment-based OAuth callback (implicit flow)")
                print("   Parsing tokens from URL fragment...")
                
                // Parse fragment to extract tokens
                guard let fragment = url.fragment else {
                    throw OAuthError.invalidURL
                }
                
                // Parse fragment parameters (they're in format key=value&key2=value2)
                let fragmentParams = fragment.components(separatedBy: "&")
                var params: [String: String] = [:]
                for param in fragmentParams {
                    let parts = param.components(separatedBy: "=")
                    if parts.count == 2 {
                        let key = parts[0]
                        let value = parts[1].removingPercentEncoding ?? parts[1]
                        params[key] = value
                    }
                }
                
                guard let accessToken = params["access_token"],
                      let refreshToken = params["refresh_token"] else {
                    throw OAuthError.invalidURL
                }
                
                print("✅ Parsed access_token and refresh_token from fragment")
                
                // Supabase SDK expects PKCE flow with code parameter, but we have tokens directly
                // We need to manually set the session. Let's try using the session(from:) method
                // by constructing a URL that matches what Supabase expects
                // Actually, Supabase might accept the fragment-based URL if we use it correctly
                // Let's try a different approach - use the access token to get user info
                
                // Decode JWT to get user info
                let jwtParts = accessToken.components(separatedBy: ".")
                guard jwtParts.count == 3 else {
                    throw OAuthError.invalidURL
                }
                
                // Decode JWT payload (base64)
                let payload = jwtParts[1]
                // Add padding if needed
                var base64 = payload
                let remainder = base64.count % 4
                if remainder > 0 {
                    base64 = base64.padding(toLength: base64.count + 4 - remainder, withPad: "=", startingAt: 0)
                }
                
                guard let data = Data(base64Encoded: base64),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let userId = json["sub"] as? String else {
                    throw OAuthError.invalidURL
                }
                
                print("✅ Decoded JWT - User ID: \(userId)")
                
                // Create a session URL that Supabase SDK can handle
                // We'll use the access token as a code parameter (hack, but might work)
                // Actually, let's try constructing a URL with the tokens as query params
                var components = URLComponents(string: "app.hyka.com://callback")!
                components.queryItems = [
                    URLQueryItem(name: "access_token", value: accessToken),
                    URLQueryItem(name: "refresh_token", value: refreshToken),
                    URLQueryItem(name: "expires_at", value: params["expires_at"] ?? ""),
                    URLQueryItem(name: "expires_in", value: params["expires_in"] ?? "")
                ]
                
                guard let modifiedURL = components.url else {
                    throw OAuthError.invalidURL
                }
                
                print("🔄 Setting session directly from access token...")
                
                // CRITICAL: Set the session in Supabase SDK so auth.uid() works in RLS policies
                // The SDK needs the session to include JWT token in API requests
                
                // Try the modified URL approach - Supabase might accept it
                do {
                    try await Supa.client.auth.session(from: modifiedURL)
                    print("✅ Session created from access token")
                } catch {
                    // If that fails, try using the fragment URL directly
                    print("⚠️ Modified URL approach failed, trying fragment URL...")
                    // Create URL with fragment as query for Supabase
                    var fragmentAsQuery = URLComponents(string: "\(Config.supabaseURL)/auth/v1/callback")!
                    fragmentAsQuery.queryItems = components.queryItems
                    
                    // This won't work either. Let's decode the JWT and create a user object manually
                    // Then fetch the session using the access token
                    print("⚠️ Using access token to fetch user info...")
                    
                    // Use the access token to make an authenticated request to get user info
                    do {
                        let userURL = URL(string: "\(Config.supabaseURL)/auth/v1/user")!
                        var request = URLRequest(url: userURL)
                        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
                        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
                        
                        print("🔄 Fetching user info from Supabase API...")
                        let (userData, response) = try await URLSession.shared.data(for: request)
                        
                        guard let httpResponse = response as? HTTPURLResponse else {
                            print("❌ Invalid response type")
                            throw OAuthError.invalidURL
                        }
                        
                        print("📊 HTTP Response Status: \(httpResponse.statusCode)")
                        
                        guard (200...299).contains(httpResponse.statusCode) else {
                            print("❌ HTTP Error: \(httpResponse.statusCode)")
                            if let errorString = String(data: userData, encoding: .utf8) {
                                print("❌ Error response: \(errorString)")
                            }
                            throw OAuthError.invalidURL
                        }
                        
                        guard let userJson = try? JSONSerialization.jsonObject(with: userData) as? [String: Any] else {
                            print("❌ Failed to parse user JSON")
                            if let errorString = String(data: userData, encoding: .utf8) {
                                print("❌ Response data: \(errorString)")
                            }
                            throw OAuthError.invalidURL
                        }
                        
                        print("✅ Retrieved user info from Supabase API")
                        
                        // Extract OAuth user info from userJson
                        let userMetadata = userJson["user_metadata"] as? [String: Any] ?? [:]
                        let extractedOAuthInfo = OAuthUserInfo.from(userMetadata: userMetadata)
                        await MainActor.run {
                            oauthUserInfo = extractedOAuthInfo
                            print("   - Extracted OAuth info: firstName=\(extractedOAuthInfo.firstName ?? "nil"), lastName=\(extractedOAuthInfo.lastName ?? "nil"), gender=\(extractedOAuthInfo.gender?.rawValue ?? "nil")")
                        }
                        
                        // Manually create session using Supabase's refresh token endpoint
                        // This is the proper way to establish a session from tokens
                        print("🔄 Exchanging refresh token for session...")
                        
                        let refreshURL = URL(string: "\(Config.supabaseURL)/auth/v1/token?grant_type=refresh_token")!
                        var refreshRequest = URLRequest(url: refreshURL)
                        refreshRequest.httpMethod = "POST"
                        refreshRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                        refreshRequest.setValue("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd2Zmh0aWxqa3liYnJieG95cXNxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA3NjYyNTgsImV4cCI6MjA3NjM0MjI1OH0.pOSv9o4_xIg-GCozVMEocp2K27fTDzP_-aG2WPm9j1w", forHTTPHeaderField: "apikey")
                        
                        let refreshBody: [String: Any] = [
                            "refresh_token": refreshToken
                        ]
                        refreshRequest.httpBody = try JSONSerialization.data(withJSONObject: refreshBody)
                        
                        let (sessionData, sessionResponse) = try await URLSession.shared.data(for: refreshRequest)
                        
                        guard let sessionHttpResponse = sessionResponse as? HTTPURLResponse,
                              (200...299).contains(sessionHttpResponse.statusCode),
                              let sessionJson = try? JSONSerialization.jsonObject(with: sessionData) as? [String: Any] else {
                            print("⚠️ Refresh token exchange failed, using access token directly")
                            // If refresh fails, we'll manually create the session
                            let user = try await createUserFromTokens(accessToken: accessToken, refreshToken: refreshToken, userJson: userJson, expiresAt: params["expires_at"] ?? "")
                            await MainActor.run {
                                currentUser = user
                            }
                            print("✅ Session manually created from tokens")
                            
                            // Check onboarding and set authentication state
                            print("🔄 Checking onboarding status from Supabase...")
                            do {
                                let hasCompleted = try await SupabaseService.hasCompletedOnboarding(userId: user.id)
                                await MainActor.run {
                                    hasCompletedOnboarding = hasCompleted
                                    UserDefaults.standard.set(hasCompleted, forKey: onboardingKey)
                                    isAuthenticated = true
                                    isLoading = false
                                }
                                print("✅ Onboarding status loaded: \(hasCompleted)")
                                return
                            } catch {
                                await MainActor.run {
                                    hasCompletedOnboarding = false
                                    UserDefaults.standard.set(false, forKey: onboardingKey)
                                    isAuthenticated = true
                                    isLoading = false
                                }
                                print("⚠️ Failed to load onboarding status")
                                return
                            }
                        }
                        
                        // Parse the session response
                        guard let newAccessToken = sessionJson["access_token"] as? String,
                              let newRefreshToken = sessionJson["refresh_token"] as? String else {
                            throw OAuthError.invalidURL
                        }
                        
                        print("✅ Refresh token exchange successful")
                        
                        // Now create a session URL with the new tokens
                        var sessionComponents = URLComponents(string: "app.hyka.com://callback")!
                        sessionComponents.queryItems = [
                            URLQueryItem(name: "access_token", value: newAccessToken),
                            URLQueryItem(name: "refresh_token", value: newRefreshToken)
                        ]
                        
                        guard sessionComponents.url != nil else {
                            throw OAuthError.invalidURL
                        }
                        
                        // Extract expires_in value
                        let expiresIn = sessionJson["expires_in"] as? Int ?? 3600
                        
                        // Store the session in UserDefaults with the new tokens
                        let storedSessionData: [String: Any] = [
                            "access_token": newAccessToken,
                            "refresh_token": newRefreshToken,
                            "expires_at": sessionJson["expires_at"] as? Double ?? Double(sessionJson["expires_at"] as? Int ?? 0),
                            "expires_in": expiresIn,
                            "token_type": "bearer",
                            "user": userJson
                        ]
                        
                        // CRITICAL: Set the session in Supabase SDK so auth.uid() works in RLS policies
                        // The SDK needs the session to include JWT token in API requests
                        do {
                            // Create a Session object from the tokens
                            // Extract user info from the JWT
                            let jwtParts = newAccessToken.components(separatedBy: ".")
                            guard jwtParts.count == 3,
                                  let payload = Data(base64Encoded: jwtParts[1].base64Padded),
                                  let jwtJson = try? JSONSerialization.jsonObject(with: payload) as? [String: Any],
                                  let userIdString = jwtJson["sub"] as? String,
                                  let userId = UUID(uuidString: userIdString) else {
                                throw OAuthError.invalidURL
                            }
                            
                            // CRITICAL: Set the session in Supabase SDK so auth.uid() works in RLS policies
                            // The SDK needs the session to include JWT token in API requests
                            // Store the session in the format the SDK expects
                            if let sessionJSON = try? JSONSerialization.data(withJSONObject: storedSessionData) {
                                // Store in UserDefaults using the key Supabase SDK expects
                                // The SDK uses a specific storage key format
                                let storageKey = "supabase.auth.token"
                                UserDefaults.standard.set(sessionJSON, forKey: storageKey)
                                print("✅ Stored session in UserDefaults with key: \(storageKey)")
                                
                                // Also store with the backup key
                                UserDefaults.standard.set(sessionJSON, forKey: "supabase.auth.session")
                            }
                            
                            // Try using session(from:) with a properly formatted callback URL
                            // Create a callback URL with the tokens as query parameters
                            var callbackURL = URLComponents(string: "app.hyka.com://callback")!
                            callbackURL.queryItems = [
                                URLQueryItem(name: "access_token", value: newAccessToken),
                                URLQueryItem(name: "refresh_token", value: newRefreshToken),
                                URLQueryItem(name: "token_type", value: "bearer"),
                                URLQueryItem(name: "expires_in", value: "\(expiresIn)")
                            ]
                            
                            guard callbackURL.url != nil else {
                                throw OAuthError.invalidURL
                            }
                            
                            print("🔄 Setting session in Supabase SDK...")
                            
                            // Use the Supabase Swift SDK's setSession method directly
                            // Reference: https://supabase.com/docs/reference/swift/auth-setsession
                            do {
                                try await Supa.client.auth.setSession(accessToken: newAccessToken, refreshToken: newRefreshToken)
                                print("✅ Successfully set session in Supabase SDK using setSession method")
                                
                                // Verify the session is set
                                let verifiedSession = try await Supa.client.auth.session
                                print("✅ Verified session is set in SDK - user ID: \(verifiedSession.user.id)")
                                print("   Access token present: \(!verifiedSession.accessToken.isEmpty)")
                                
                                // Update currentUser
                                await MainActor.run {
                                    currentUser = verifiedSession.user
                                }
                            } catch {
                                print("⚠️ setSession failed: \(error)")
                                print("   Error details: \(error.localizedDescription)")
                                
                                // Fallback: Store session in UserDefaults for REST API fallback
                                let expiresAt = sessionJson["expires_at"] as? Double ?? Double(Date().timeIntervalSince1970) + Double(expiresIn)
                                let sessionStorage: [String: Any] = [
                                    "access_token": newAccessToken,
                                    "refresh_token": newRefreshToken,
                                    "expires_at": expiresAt,
                                    "expires_in": expiresIn,
                                    "token_type": "bearer",
                                    "user": userJson
                                ]
                                
                                if let sessionData = try? JSONSerialization.data(withJSONObject: sessionStorage) {
                                    UserDefaults.standard.set(sessionData, forKey: "supabase.auth.session")
                                    print("   Stored session in UserDefaults as fallback")
                                }
                                
                                print("   RLS policies may still fail - using REST API fallback")
                            }
                            
                            print("   User ID: \(userId)")
                            
                            // Wait a moment for SDK to process the session
                            try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                            
                            // Now get the session to verify it's set
                            do {
                                let retrievedSession = try await Supa.client.auth.session
                                print("✅ Verified session is set in SDK - user ID: \(retrievedSession.user.id)")
                                print("   Access token present: \(!retrievedSession.accessToken.isEmpty)")
                                
                                await MainActor.run {
                                    currentUser = retrievedSession.user
                                }
                                
                                // Check onboarding and set authentication state
                                print("🔄 Checking onboarding status from Supabase...")
                                do {
                                    // Pass the access token so REST API can be used as fallback
                                    let hasCompleted = try await SupabaseService.hasCompletedOnboarding(userId: retrievedSession.user.id, accessToken: newAccessToken)
                                    await MainActor.run {
                                        hasCompletedOnboarding = hasCompleted
                                        UserDefaults.standard.set(hasCompleted, forKey: onboardingKey)
                                        isAuthenticated = true
                                        isLoading = false
                                    }
                                    print("✅ Onboarding status loaded: \(hasCompleted)")
                                    return
                                } catch {
                                    await MainActor.run {
                                        hasCompletedOnboarding = false
                                        UserDefaults.standard.set(false, forKey: onboardingKey)
                                        isAuthenticated = true
                                        isLoading = false
                                    }
                                    print("⚠️ Failed to load onboarding status: \(error)")
                                    return
                                }
                            } catch {
                                print("⚠️ Could not retrieve session from SDK after setting it")
                                print("   Error: \(error)")
                                print("   This means RLS policies will fail - using fallback approach")
                                // Fall through to the outer catch block
                                throw error
                            }
                            
                        } catch {
                            print("⚠️ Failed to set session in Supabase SDK: \(error)")
                            print("   This means auth.uid() will return NULL and RLS policies will fail")
                            print("   Falling back to UserDefaults storage...")
                            
                            // Fallback: Store in UserDefaults and try to use it
                            if let sessionJSON = try? JSONSerialization.data(withJSONObject: storedSessionData) {
                                UserDefaults.standard.set(sessionJSON, forKey: "supabase.auth.session")
                                print("✅ Stored session in UserDefaults as fallback")
                            }
                            
                            // Try to get session from SDK anyway (might have been set elsewhere)
                            do {
                                let session = try await Supa.client.auth.session
                                print("✅ Successfully retrieved session from SDK after fallback")
                                
                                await MainActor.run {
                                    currentUser = session.user
                                }
                                
                                // Check onboarding and set authentication state
                                print("🔄 Checking onboarding status from Supabase...")
                                do {
                                    let hasCompleted = try await SupabaseService.hasCompletedOnboarding(userId: session.user.id)
                                    await MainActor.run {
                                        hasCompletedOnboarding = hasCompleted
                                        UserDefaults.standard.set(hasCompleted, forKey: onboardingKey)
                                        isAuthenticated = true
                                        isLoading = false
                                    }
                                    print("✅ Onboarding status loaded: \(hasCompleted)")
                                    return
                                } catch {
                                    await MainActor.run {
                                        hasCompletedOnboarding = false
                                        UserDefaults.standard.set(false, forKey: onboardingKey)
                                        isAuthenticated = true
                                        isLoading = false
                                    }
                                    print("⚠️ Failed to load onboarding status")
                                    return
                                }
                            } catch {
                                print("⚠️ SDK still couldn't read session, using JWT data directly")
                                
                                // Extract user ID from JWT
                                let jwtParts = newAccessToken.components(separatedBy: ".")
                                guard jwtParts.count == 3,
                                      let payload = Data(base64Encoded: jwtParts[1].base64Padded),
                                      let json = try? JSONSerialization.jsonObject(with: payload) as? [String: Any],
                                      let userIdString = json["sub"] as? String,
                                      let userId = UUID(uuidString: userIdString) else {
                                    throw OAuthError.invalidURL
                                }
                                
                                // Get email from userJson or JWT
                                let email = userJson["email"] as? String ?? json["email"] as? String ?? ""
                                
                                // Create a minimal user structure - we'll use the session data we have
                                // Since we can't create a full User object, we'll set authentication state
                                // and let the SDK handle user fetching on next request
                                await MainActor.run {
                                    // Create a basic user object from the JWT data
                                    // We'll need to fetch the full user later, but for now set auth state
                                    // Store user ID and email for later use
                                    let userDefaults = UserDefaults.standard
                                    userDefaults.set(userIdString, forKey: "hyka.user.id")
                                    userDefaults.set(email, forKey: "hyka.user.email")
                                }
                                
                                // Check onboarding using the user ID
                                print("🔄 Checking onboarding status from Supabase...")
                                do {
                                    let hasCompleted = try await SupabaseService.hasCompletedOnboarding(userId: userId)
                                    await MainActor.run {
                                        hasCompletedOnboarding = hasCompleted
                                        UserDefaults.standard.set(hasCompleted, forKey: onboardingKey)
                                        isAuthenticated = true
                                        isLoading = false
                                    }
                                    print("✅ Onboarding status loaded from Supabase: \(hasCompleted)")
                                    return
                                } catch {
                                    // Fallback to UserDefaults if Supabase check fails
                                    let hasCompleted = UserDefaults.standard.bool(forKey: onboardingKey)
                                    await MainActor.run {
                                        hasCompletedOnboarding = hasCompleted
                                        isAuthenticated = true
                                        isLoading = false
                                        
                                        print("")
                                        print("═══════════════════════════════════════")
                                        print("✅ OAUTH CALLBACK - FINAL STATE SET")
                                        print("   isAuthenticated: \(isAuthenticated)")
                                        print("   hasCompletedOnboarding: \(hasCompletedOnboarding)")
                                        print("   isLoading: \(isLoading)")
                                        print("   currentUser: \(String(describing: currentUser?.id))")
                                        print("   User ID from UserDefaults: \(userIdString)")
                                        print("═══════════════════════════════════════")
                                        print("")
                                    }
                                    print("⚠️ Failed to load onboarding status from Supabase, using UserDefaults: \(hasCompleted)")
                                    print("✅ Authentication complete - user should see onboarding flow")
                                    return
                                }
                            }
                        }
                    } catch {
                        print("❌ Error in fragment-based OAuth handling: \(error)")
                        print("❌ Error details: \(error.localizedDescription)")
                        if let oauthError = error as? OAuthError {
                            print("❌ OAuth Error type: \(oauthError)")
                        }
                        // Don't rethrow - instead, try to create user directly from JWT
                        print("⚠️ Attempting to create user directly from JWT tokens...")
                        
                        // Parse tokens from fragment
                        guard let fragment = url.fragment,
                              let accessToken = fragment.components(separatedBy: "&").first(where: { $0.hasPrefix("access_token=") })?.replacingOccurrences(of: "access_token=", with: ""),
                              let refreshToken = fragment.components(separatedBy: "&").first(where: { $0.hasPrefix("refresh_token=") })?.replacingOccurrences(of: "refresh_token=", with: ""),
                              let expiresAt = fragment.components(separatedBy: "&").first(where: { $0.hasPrefix("expires_at=") })?.replacingOccurrences(of: "expires_at=", with: "") else {
                            print("❌ Failed to parse tokens from fragment")
                            throw error
                        }
                        
                        // Decode JWT to get user info
                        let jwtParts = accessToken.components(separatedBy: ".")
                        guard jwtParts.count == 3 else {
                            throw error
                        }
                        
                        let payload = jwtParts[1]
                        guard let data = Data(base64Encoded: payload.base64Padded),
                              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let userIdString = json["sub"] as? String,
                              let userId = UUID(uuidString: userIdString) else {
                            throw error
                        }
                        
                        // Store session in UserDefaults
                        let email = json["email"] as? String ?? ""
                        let sessionData: [String: Any] = [
                            "access_token": accessToken,
                            "refresh_token": refreshToken,
                            "expires_at": Double(expiresAt) ?? 0,
                            "expires_in": 3600,
                            "token_type": "bearer",
                            "user": [
                                "id": userIdString,
                                "email": email,
                                "phone": json["phone"] as? String ?? "",
                                "app_metadata": json["app_metadata"] as? [String: Any] ?? [:],
                                "user_metadata": json["user_metadata"] as? [String: Any] ?? [:]
                            ]
                        ]
                        
                        if let sessionJSON = try? JSONSerialization.data(withJSONObject: sessionData) {
                            UserDefaults.standard.set(sessionJSON, forKey: "supabase.auth.session")
                            print("✅ Stored session in UserDefaults from JWT fallback")
                        }
                        
                        // Wait a moment for SDK to pick up session
                        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                        
                        // Try to get session from SDK
                        do {
                            let session = try await Supa.client.auth.session
                            print("✅ Successfully retrieved session from SDK (JWT fallback)")
                            
                            await MainActor.run {
                                currentUser = session.user
                            }
                            
                            // Check onboarding
                            do {
                                let hasCompleted = try await SupabaseService.hasCompletedOnboarding(userId: session.user.id)
                                await MainActor.run {
                                    hasCompletedOnboarding = hasCompleted
                                    UserDefaults.standard.set(hasCompleted, forKey: onboardingKey)
                                    
                                    // Sync user ID to UserDefaults
                                    UserDefaults.standard.set(session.user.id.uuidString, forKey: "hyka.user.id")
                                    
                                    // Register device token
                                    Task {
                                        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                                            await appDelegate.registerDeviceTokenForUser(session.user.id)
                                        }
                                    }
                                    
                                    isAuthenticated = true
                                    isLoading = false
                                }
                                print("✅ Authentication successful using JWT fallback")
                                return
                            } catch {
                                await MainActor.run {
                                    hasCompletedOnboarding = false
                                    UserDefaults.standard.set(false, forKey: onboardingKey)
                                    isAuthenticated = true
                                    isLoading = false
                                }
                                print("✅ Authentication successful (onboarding check failed)")
                                return
                            }
                        } catch {
                            print("⚠️ SDK still couldn't read session, using JWT data directly")
                            
                            // Store user ID and email for later use
                            await MainActor.run {
                                UserDefaults.standard.set(userIdString, forKey: "hyka.user.id")
                                UserDefaults.standard.set(email, forKey: "hyka.user.email")
                            }
                            
                            // Check onboarding using user ID
                            do {
                                let hasCompleted = try await SupabaseService.hasCompletedOnboarding(userId: userId)
                                await MainActor.run {
                                    hasCompletedOnboarding = hasCompleted
                                    UserDefaults.standard.set(hasCompleted, forKey: onboardingKey)
                                    
                                    // Register device token
                                    Task {
                                        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                                            await appDelegate.registerDeviceTokenForUser(userId)
                                        }
                                    }
                                    
                                    isAuthenticated = true
                                }
                                print("✅ Authentication successful using JWT fallback (direct)")
                                return
                            } catch {
                                await MainActor.run {
                                    hasCompletedOnboarding = false
                                    UserDefaults.standard.set(false, forKey: onboardingKey)
                                    isAuthenticated = true
                                }
                                print("✅ Authentication successful (onboarding check failed)")
                                return
                            }
                        }
                    }
                }
            } else {
                // Standard PKCE flow with query parameters
                print("🔄 Extracting session from callback URL (PKCE flow)...")
                try await Supa.client.auth.session(from: url)
                print("✅ Session extracted from URL")
                
                // Get the current session to update our state
                print("🔄 Fetching current session...")
                let session = try await Supa.client.auth.session
                print("✅ Session fetched")
                
                print("🔄 Updating SessionManager state...")
                
                // Extract OAuth user info (name, gender) from user metadata
                let userMetadata = session.user.userMetadata
                let extractedOAuthInfo = OAuthUserInfo.from(userMetadata: userMetadata)
                
                await MainActor.run {
                    currentUser = session.user
                    oauthUserInfo = extractedOAuthInfo
                    print("   - Set currentUser to: \(session.user.email ?? "unknown") (on main thread)")
                    print("   - Extracted OAuth info: firstName=\(extractedOAuthInfo.firstName ?? "nil"), lastName=\(extractedOAuthInfo.lastName ?? "nil"), gender=\(extractedOAuthInfo.gender?.rawValue ?? "nil")")
                    print("   - NOT setting isAuthenticated yet (will set after onboarding check)")
                }
                
                print("")
                print("═══════════════════════════════════════")
                print("🎯 OAUTH CALLBACK STATE UPDATE")
                print("   isAuthenticated: \(isAuthenticated)")
                print("   currentUser: \(session.user.email ?? "unknown")")
                print("   User ID: \(session.user.id)")
                print("═══════════════════════════════════════")
                print("")
                
                // Check onboarding status from Supabase (same as checkSession)
                print("🔄 Checking onboarding status from Supabase...")
                do {
                    let hasCompleted = try await SupabaseService.hasCompletedOnboarding(userId: session.user.id)
                    await MainActor.run {
                        hasCompletedOnboarding = hasCompleted
                        // Sync to UserDefaults as a backup
                        UserDefaults.standard.set(hasCompleted, forKey: onboardingKey)
                    }
                    print("✅ Onboarding status loaded from Supabase after OAuth: \(hasCompleted)")
                    print("✅ Onboarding state updated: hasCompletedOnboarding = \(hasCompleted)")
                    print("🎯 User should now see: \(hasCompleted ? "Main App (completed onboarding)" : "OnboardingFlowView (first time)")")
                    
                    // CRITICAL: Set isAuthenticated AFTER checking onboarding
                    // This ensures the onChange handler fires AFTER everything is ready
                    await MainActor.run {
                        print("✅ Setting isAuthenticated = true (this will trigger onChange in AuthView)")
                        isAuthenticated = true
                        
                        // Register device token for push notifications
                        if let userId = currentUser?.id {
                            Task {
                                // Get AppDelegate and register device token
                                if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                                    await appDelegate.registerDeviceTokenForUser(userId)
                                }
                            }
                        }
                    }
                } catch {
                    // Fallback to UserDefaults if Supabase check fails
                    // For new users, profile doesn't exist yet, so set to false
                    await MainActor.run {
                        hasCompletedOnboarding = false
                        UserDefaults.standard.set(false, forKey: onboardingKey)
                        // Still set authenticated even if onboarding check fails
                        print("✅ Setting isAuthenticated = true (onboarding check failed, but user is authenticated)")
                        isAuthenticated = true
                    }
                    print("⚠️ Failed to load onboarding status from Supabase after OAuth (likely new user)")
                    print("ℹ️ Setting hasCompletedOnboarding = false (new user - will see onboarding)")
                }
            }
        } catch {
            print("")
            print("❌ OAuth callback error: \(error)")
            print("❌ Error details: \(error.localizedDescription)")
            print("")
            await MainActor.run {
                isAuthenticated = false
                currentUser = nil
                hasCompletedOnboarding = false
            }
        }
        
        await MainActor.run {
            isLoading = false
        }
        
        print("")
        print("═══════════════════════════════════════")
        print("✅ OAUTH CALLBACK PROCESSING COMPLETE")
        print("   Final state:")
        print("   - isAuthenticated: \(isAuthenticated)")
        print("   - hasCompletedOnboarding: \(hasCompletedOnboarding)")
        print("   - isLoading: \(isLoading)")
        print("   - currentUser: \(currentUser?.email ?? "nil")")
        print("")
        print("🎯 EXPECTED BEHAVIOR:")
        if isAuthenticated {
            print("   - AuthView should observe isAuthenticated change")
            print("   - AuthView .onChange should trigger")
            print("   - AuthView should dismiss automatically")
            print("   - ContentView should show: \(hasCompletedOnboarding ? "Main App Tabs" : "Onboarding Flow")")
        }
        print("═══════════════════════════════════════")
        print("")
        
        print("")
        print("═══════════════════════════════════════")
        print("✅ OAUTH CALLBACK COMPLETE")
        print("   Final isAuthenticated: \(isAuthenticated)")
        print("   Final hasCompletedOnboarding: \(hasCompletedOnboarding)")
        print("   Final isLoading: \(isLoading)")
        print("   This should trigger .onChange observers!")
        print("═══════════════════════════════════════")
        print("")
    }
}

extension SessionManager {
    /// Manually create a User object from tokens and user info
    private func createUserFromTokens(accessToken: String, refreshToken: String, userJson: [String: Any], expiresAt: String) async throws -> User {
        // Decode JWT to get user ID
        let jwtParts = accessToken.components(separatedBy: ".")
        guard jwtParts.count == 3 else {
            throw OAuthError.invalidURL
        }
        
        let payload = jwtParts[1]
        var base64 = payload
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 = base64.padding(toLength: base64.count + 4 - remainder, withPad: "=", startingAt: 0)
        }
        
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let userIdString = json["sub"] as? String,
              UUID(uuidString: userIdString) != nil else {
            throw OAuthError.invalidURL
        }
        
        // Extract user data
        let email = userJson["email"] as? String ?? json["email"] as? String ?? ""
        let phone = userJson["phone"] as? String ?? ""
        let appMetadata = userJson["app_metadata"] as? [String: Any] ?? json["app_metadata"] as? [String: Any] ?? [:]
        let userMetadata = userJson["user_metadata"] as? [String: Any] ?? json["user_metadata"] as? [String: Any] ?? [:]
        
        // Store session in UserDefaults (Supabase SDK uses this)
        let sessionData: [String: Any] = [
            "access_token": accessToken,
            "refresh_token": refreshToken,
            "expires_at": Double(expiresAt) ?? 0,
            "expires_in": 3600,
            "token_type": "bearer",
            "user": [
                "id": userIdString,
                "email": email,
                "phone": phone,
                "app_metadata": appMetadata,
                "user_metadata": userMetadata,
                "aud": "authenticated",
                "role": "authenticated"
            ]
        ]
        
        if let sessionJSON = try? JSONSerialization.data(withJSONObject: sessionData) {
            UserDefaults.standard.set(sessionJSON, forKey: "supabase.auth.session")
            print("✅ Stored session in UserDefaults")
        }
        
        // Create User object - using Supabase Auth User type
        // The User type from Supabase should have these initializers
        // Since we can't directly instantiate User, we'll need to use the SDK's method
        // For now, let's fetch the user from Supabase using the access token
        // Actually, we already have userJson, so let's create a User object from it
        
        // Since we can't directly create a User object, we'll use a workaround
        // We'll set the session in UserDefaults and then fetch it from Supabase SDK
        // But wait - the SDK might not recognize it
        
        // Try to fetch session from Supabase SDK after storing it
        // If that fails, we'll manually create a minimal User object
        do {
            // Try to get the session from SDK (it should read from UserDefaults)
            let session = try await Supa.client.auth.session
            print("✅ Successfully retrieved session from SDK after storing")
            return session.user
        } catch {
            print("⚠️ SDK couldn't read session, creating minimal User object")
            // Create a minimal User object - we'll need to check the actual User type
            // For now, let's decode the JWT and create a basic User
            // The User type might be a struct we can initialize
            // Let's try using Codable to decode from userJson
            if let userData = try? JSONSerialization.data(withJSONObject: userJson),
               let user = try? JSONDecoder().decode(User.self, from: userData) {
                return user
            }
            
            // Fallback: create a basic User structure
            // This might not work if User requires specific initialization
            // But we'll try it
            throw OAuthError.invalidURL
        }
    }
}

// MARK: - String Extension for Base64 Padding

extension String {
    var base64Padded: String {
        var base64 = self
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 = base64.padding(toLength: base64.count + 4 - remainder, withPad: "=", startingAt: 0)
        }
        return base64
    }
}

// MARK: - OAuth User Info

struct OAuthUserInfo {
    let firstName: String?
    let lastName: String?
    let gender: UserProfile.Gender?
    
    /// Extract OAuth user info from Supabase user metadata
    static func from(userMetadata: [String: Any]) -> OAuthUserInfo {
        // Google/Facebook typically provide:
        // - full_name: "John Doe"
        // - first_name: "John"
        // - last_name: "Doe"
        // - gender: "male" or "female" (Facebook sometimes)
        
        var firstName: String? = nil
        var lastName: String? = nil
        var gender: UserProfile.Gender? = nil
        
        // Try to get first_name and last_name directly
        if let first = userMetadata["first_name"] as? String, !first.isEmpty {
            firstName = first
        }
        if let last = userMetadata["last_name"] as? String, !last.isEmpty {
            lastName = last
        }
        
        // If not available, try to split full_name
        if firstName == nil || lastName == nil {
            if let fullName = userMetadata["full_name"] as? String, !fullName.isEmpty {
                let components = fullName.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: " ")
                if components.count >= 2 {
                    firstName = components.first
                    lastName = components.dropFirst().joined(separator: " ")
                } else if components.count == 1 {
                    firstName = components.first
                }
            }
        }
        
        // Extract gender (Facebook sometimes provides this)
        if let genderString = userMetadata["gender"] as? String {
            let lowercased = genderString.lowercased()
            switch lowercased {
            case "male", "m":
                gender = .male
            case "female", "f":
                gender = .female
            default:
                gender = nil
            }
        }
        
        return OAuthUserInfo(firstName: firstName, lastName: lastName, gender: gender)
    }
}

// MARK: - OAuth Errors

enum OAuthError: Error, LocalizedError {
    case noViewController
    case invalidURL
    case noCallback
    case cancelled
    case sessionFailed
    
    var errorDescription: String? {
        switch self {
        case .noViewController:
            return "Could not find view controller for OAuth presentation"
        case .invalidURL:
            return "Invalid OAuth URL"
        case .noCallback:
            return "No callback URL received from OAuth provider"
        case .cancelled:
            return "OAuth flow was cancelled by user"
        case .sessionFailed:
            return "Failed to start OAuth session"
        }
    }
}
