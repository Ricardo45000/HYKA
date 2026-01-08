import Foundation
import SwiftUI
import Combine
import AuthenticationServices
import Auth
import Supabase
import ObjectiveC
import CryptoKit

/// Unified OAuth manager for fitness device providers (Garmin, Coros, Suunto, Polar)
@MainActor
final class DeviceOAuthManager: ObservableObject {
    @Published var isConnecting = false
    @Published var connectingProvider: String?
    @Published var errorMessage: String?
    
    private weak var session: SessionManager?
    
    init(session: SessionManager) {
        self.session = session
    }
    
    func setSession(_ session: SessionManager) {
        self.session = session
    }
    
    /// Connect to a provider via OAuth (or HealthKit for Apple)
    func connectProvider(_ provider: String, from viewController: UIViewController) async throws {
        guard let session = session else {
            throw DeviceOAuthError.notAuthenticated
        }
        
        // Get user ID from currentUser or fallback to UserDefaults
        var userId: UUID?
        
        if let user = session.currentUser {
            userId = user.id
        } else if session.isAuthenticated {
            // Fallback: Check UserDefaults for user ID (set during OAuth fallback)
            if let userIdString = UserDefaults.standard.string(forKey: "hyka.user.id"),
               let id = UUID(uuidString: userIdString) {
                userId = id
                print("✅ Using user ID from UserDefaults: \(userIdString)")
            }
        }
        
        guard let userId = userId else {
            print("❌ No user ID available - isAuthenticated: \(session.isAuthenticated), currentUser: \(session.currentUser?.id ?? nil)")
            throw DeviceOAuthError.notAuthenticated
        }
        
        isConnecting = true
        connectingProvider = provider
        errorMessage = nil
        
        defer {
            isConnecting = false
            connectingProvider = nil
        }
        
        var connectionSaved = false
        
        do {
            let (accessToken, refreshToken, tokenSecret, expiresAt) = try await performOAuth(for: provider, from: viewController)
            
            
            // Save connection to database first (so user can manually sync if initial fetch fails)
            // NOTE: For Strava, the Edge Function (strava-auth-callback) already saves to strava_connections
            // So we skip the iOS save to avoid duplicate/conflicting entries
            if provider.lowercased() != "strava" {
                try await SupabaseService.saveOAuthConnection(
                    userId: userId,
                    provider: provider.lowercased(),
                    accessToken: accessToken,
                    refreshToken: refreshToken,
                    tokenSecret: tokenSecret,
                    expiresAt: expiresAt
                )
                connectionSaved = true
                print("✅ OAuth connection saved for \(provider)")
            } else {
                // Strava connection is already saved by strava-auth-callback Edge Function
                connectionSaved = true
                print("✅ Strava connection already saved by Edge Function")
            }
            
            // Trigger server-side historical backfill (30 days)
            // This happens automatically after user successfully connects and agrees to share data
            do {
                print("🔄 Triggering historical sync for \(provider) (last 30 days)...")
                try await triggerHistoricalSync(userId: userId, provider: provider.lowercased())
                print("✅ Historical sync requested successfully for \(provider)")
                
                // Show specific alert for Garmin sync delay
                if provider.lowercased() == "garmin" {
                    await MainActor.run {
                        ErrorManager.shared.showError(
                            title: "Sync in Progress",
                            message: "Garmin historical data sync has started. Your activities will appear in about 15 minutes."
                        )
                    }
                } else {
                    // For other providers, show a brief success message
                    await MainActor.run {
                        ErrorManager.shared.showError(
                            title: "Sync Started",
                            message: "\(provider.capitalized) historical data sync has started. Your activities will appear shortly."
                        )
                    }
                }
            } catch {
                print("❌ Error triggering historical sync for \(provider): \(error)")
                // Show error to user so they know sync failed
                await MainActor.run {
                    ErrorManager.shared.showError(
                        title: "Sync Failed",
                        message: "Failed to start \(provider.capitalized) historical sync. Please try syncing manually from the app."
                    )
                }
            }
            
            // Automatically fetch and store health metrics after connection - push to database immediately
            do {
                try await fetchAndStoreHealthMetrics(userId: userId, provider: provider.lowercased(), accessToken: accessToken)
            } catch {
                // Log error but don't fail the connection if health metrics fail
                print("⚠️ Error fetching health metrics (connection still successful): \(error)")
                ErrorManager.shared.showError(error, title: "Health Data Sync")
            }
            
            // Automatically fetch and store training data after connection - push to database immediately
            do {
                try await fetchAndStoreTraining(userId: userId, provider: provider.lowercased(), accessToken: accessToken)
            } catch {
                // Log error but don't fail the connection if training data fails
                print("⚠️ Error fetching training data (connection still successful): \(error)")
                ErrorManager.shared.showError(error, title: "Training Data Sync")
            }
            
        } catch {
            // If connection was saved but an error occurred, clean it up
            if connectionSaved {
                do {
                    try await SupabaseService.deleteOAuthConnection(userId: userId, provider: provider.lowercased())
                    print("🧹 Cleaned up connection after error")
                } catch {
                    print("⚠️ Failed to clean up connection after error: \(error)")
                }
            }
            
            errorMessage = error.localizedDescription
            print("❌ Error connecting to \(provider): \(error)")
            ErrorManager.shared.showError(error, title: "Connection Failed")
            throw error
        }
    }
    
    // MARK: - OAuth Implementation
    
    private func performOAuth(for provider: String, from viewController: UIViewController) async throws -> (accessToken: String, refreshToken: String?, tokenSecret: String?, expiresAt: Date?) {
        switch provider.lowercased() {
        case "garmin":
            // Garmin uses OAuth 2.0 with PKCE for all APIs
            let (accessToken, refreshToken, expiresIn) = try await performGarminOAuth(from: viewController)
            // Calculate expiration date (subtract 600 seconds as recommended by Garmin docs)
            let expiresAt = expiresIn.map { Date().addingTimeInterval(TimeInterval($0 - 600)) }
            return (accessToken, refreshToken, nil, expiresAt) // OAuth 2.0: no token secret
            
        case "coros":
            // Coros uses OAuth 2.0
            throw DeviceOAuthError.notImplemented("Coros OAuth - Check Coros API documentation")
            
        case "suunto":
            // Suunto uses OAuth 2.0 (Suunto Plus API)
            let (accessToken, refreshToken, expiresAt) = try await performSuuntoOAuth(from: viewController)
            return (accessToken, refreshToken, nil, expiresAt) // OAuth 2.0: no token secret
            
        case "polar":
            let (accessToken, refreshToken, expiresAt) = try await performPolarOAuth(from: viewController)
            return (accessToken, refreshToken, nil, expiresAt) // OAuth 2.0 doesn't have token secret
            
        case "strava":
            // Strava uses OAuth 2.0
            let (accessToken, refreshToken, expiresAt) = try await performStravaOAuth(from: viewController)
            return (accessToken, refreshToken, nil, expiresAt) // OAuth 2.0: no token secret
            
        default:
            throw DeviceOAuthError.unknownProvider(provider)
        }
    }
    
    private func performGarminOAuth(from viewController: UIViewController) async throws -> (accessToken: String, refreshToken: String?, expiresIn: Int?) {
        // Garmin Connect OAuth 2.0 with PKCE
        // Note: client_secret is now stored securely in Supabase Edge Function
        let clientId = Config.garminClientID
        // Use custom URL scheme for mobile OAuth (required for ASWebAuthenticationSession)
        // This must match the callbackURLScheme below and be registered in Garmin Developer Portal
        let redirectURI = Config.garminRedirectURI
        
        print("🔄 Garmin OAuth 2.0 with PKCE Flow")
        print("   Client ID: \(clientId.prefix(20))...")
        print("   Redirect URI: \(redirectURI)")
        
        // Generate PKCE code verifier and challenge
        let codeVerifier = generateCodeVerifier()
        let codeChallenge = generateCodeChallenge(from: codeVerifier)
        
        // Build authorization URL (OAuth 2.0 PKCE - Step 1)
        // Reference: https://developerportal.garmin.com/sites/default/files/OAuth2PKCE_1.pdf
        var components = URLComponents(string: "https://connect.garmin.com/oauth2Confirm")!
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "redirect_uri", value: redirectURI)
        ]
        
        guard let authURL = components.url else {
            throw DeviceOAuthError.invalidURL
        }
        
        print("🔗 Authorization URL: \(authURL.absoluteString.prefix(100))...")
        
        // Present authentication session
        let callbackURL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            let presentationContextProvider = AuthPresentationContextProvider(viewController: viewController)
            
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: "app.hyka.com" // Must match the scheme in redirectURI
            ) { callbackURL, error in
                if let error = error {
                    // Check if it's a Cloudflare-related error
                    let errorDescription = error.localizedDescription.lowercased()
                    if errorDescription.contains("cloudflare") || errorDescription.contains("challenge") {
                        print("⚠️ Cloudflare challenge detected in OAuth flow")
                        print("   Error: \(error.localizedDescription)")
                        // Return a specific error that we can handle
                        continuation.resume(throwing: DeviceOAuthError.cloudflareBlocked)
                        return
                    }
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let callbackURL = callbackURL else {
                    continuation.resume(throwing: DeviceOAuthError.invalidCallback)
                    return
                }
                
                continuation.resume(returning: callbackURL)
            }
            
            // IMPORTANT: Must set presentation context provider BEFORE calling start()
            session.presentationContextProvider = presentationContextProvider
            // Set to true to ensure a clean session every time.
            // This fixes issues where "bad" cookies cause 500 errors on Garmin's side.
            session.prefersEphemeralWebBrowserSession = true
            
            print("🌐 Starting OAuth session...")
            print("   URL: \(authURL.absoluteString)")
            print("   Callback scheme: app.hyka.com")
            print("   Ephemeral session: true")
            
            if !session.start() {
                print("❌ Failed to start OAuth session")
                continuation.resume(throwing: DeviceOAuthError.invalidURL)
            }
        }
        
        print("✅ Received callback: \(callbackURL.absoluteString)")
        
        // Extract authorization code
        guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false) else {
            print("❌ Failed to parse callback URL into components")
            throw DeviceOAuthError.invalidCallback
        }
        
        print("📋 Query items: \(components.queryItems?.map { "\($0.name)=\($0.value ?? "nil")" }.joined(separator: "&") ?? "none")")
        
        guard let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            print("❌ No 'code' parameter found in callback URL")
            print("   Available parameters: \(components.queryItems?.map { $0.name }.joined(separator: ", ") ?? "none")")
            throw DeviceOAuthError.invalidCallback
        }
        
        print("✅ Authorization code: \(code.prefix(20))...")
        
        // Exchange code for access token via Supabase Edge Function (OAuth 2.0 PKCE - Step 2)
        // This keeps the client_secret secure on the server
        // Updated to use garmin-auth-callback which stores connection and fetches garmin_user_id
        let edgeFunctionURL = URL(string: Config.garminAuthCallbackURL)!
        var request = URLRequest(url: edgeFunctionURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add Supabase anon key for authentication (required by Edge Functions)
        let supabaseAnonKey = Config.supabaseAnonKey
        request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        
        // Get user's Supabase user ID
        let userId: String
        do {
            let session = try await Supa.client.auth.session
            userId = session.user.id.uuidString
            print("🔑 Using user's Supabase user ID: \(userId)")
        } catch {
            print("❌ Could not get user session")
            throw DeviceOAuthError.tokenExchangeFailed
        }
        
        // Request body with code, code_verifier, redirect_uri, and user_id
        // The Edge Function will:
        // 1. Exchange code for tokens
        // 2. Fetch Garmin user ID
        // 3. Store connection in garmin_connections table
        let requestBody: [String: Any] = [
            "code": code,
            "code_verifier": codeVerifier,
            "redirect_uri": redirectURI,
            "user_id": userId
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        print("🔐 Exchanging authorization code for access token via Supabase Edge Function...")
        print("   Edge Function URL: \(edgeFunctionURL.absoluteString)")
        print("   Code: \(code.prefix(20))...")
        print("   Code Verifier: \(codeVerifier.prefix(20))...")
        print("   Redirect URI: \(redirectURI)")
        print("   User ID: \(userId)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DeviceOAuthError.invalidResponse
        }
        
        print("📡 Edge Function response: \(httpResponse.statusCode)")
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Token exchange failed: \(errorString)")
            throw DeviceOAuthError.tokenExchangeFailed
        }
        
        let tokenResponse = try JSONDecoder().decode(GarminTokenResponse.self, from: data)
        
        print("✅ Access token received: \(tokenResponse.accessToken.prefix(20))...")
        if let refreshToken = tokenResponse.refreshToken {
            print("✅ Refresh token received: \(refreshToken.prefix(20))...")
        }
        if let expiresIn = tokenResponse.expiresIn {
            print("✅ Token expires in: \(expiresIn) seconds")
        }
        
        // Return access token, refresh token, and expiration time
        // OAuth 2.0 doesn't use token secret
        return (tokenResponse.accessToken, tokenResponse.refreshToken, tokenResponse.expiresIn)
    }
    
    // Note: PKCE helper methods are defined at the end of the file
    
    // MARK: - OAuth 1.0a Helper Methods (Legacy - not used for Garmin)
    
    /// Step 1: Request a request token from Garmin
    private func requestGarminToken(
        consumerKey: String,
        consumerSecret: String,
        callbackURL: String
    ) async throws -> (requestToken: String, requestTokenSecret: String) {
        // Garmin OAuth 1.0a endpoint - use connectapi.garmin.com (API domain)
        let requestTokenEndpoints = [
            "https://connectapi.garmin.com/oauth-service/oauth/request_token"
        ]
        
        var lastError: Error?
        for endpointString in requestTokenEndpoints {
            guard let requestTokenURL = URL(string: endpointString) else { continue }
            
            // OAuth 1.0a parameters
            var parameters: [String: String] = [:]
            parameters["oauth_callback"] = callbackURL
            
            // Generate OAuth 1.0a authorization header
            // IMPORTANT: Generate timestamp and nonce as close as possible to request time
            // to minimize clock skew issues with Garmin's strict validation
            let authHeader = OAuth1Helper.generateAuthorizationHeader(
                consumerKey: consumerKey,
                consumerSecret: consumerSecret,
                token: nil,
                tokenSecret: nil,
                method: "POST",
                url: requestTokenURL,
                parameters: parameters
            )
            
            print("🔐 Requesting Garmin request token...")
            print("   URL: \(requestTokenURL.absoluteString)")
            print("   Auth Header: \(authHeader.prefix(100))...")
            
            // Create request immediately after generating auth header to minimize timestamp drift
            var request = URLRequest(url: requestTokenURL)
            request.httpMethod = "POST"
            request.setValue(authHeader, forHTTPHeaderField: "Authorization")
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            // Add User-Agent header (Garmin may expect this)
            request.setValue("HYKA/1.0", forHTTPHeaderField: "User-Agent")
            
            // Include oauth_callback in the request body as form-url-encoded parameter
            if let encodedCallback = callbackURL.addingPercentEncoding(withAllowedCharacters: CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")) {
                let bodyString = "oauth_callback=\(encodedCallback)"
                request.httpBody = bodyString.data(using: .utf8)
                print("   Body: \(bodyString)")
            } else {
                request.httpBody = "oauth_callback=\(callbackURL)".data(using: .utf8)
                print("   Body: oauth_callback=\(callbackURL)")
            }
            
            // Set timeout to ensure request is sent quickly
            request.timeoutInterval = 30.0
            
            // Debug: Log the exact request details
            print("📤 Request Details:")
            print("   Method: \(request.httpMethod ?? "N/A")")
            print("   URL: \(request.url?.absoluteString ?? "N/A")")
            print("   Headers:")
            if let headers = request.allHTTPHeaderFields {
                for (key, value) in headers.sorted(by: { $0.key < $1.key }) {
                    if key == "Authorization" {
                        print("     \(key): \(value.prefix(150))...")
                    } else {
                        print("     \(key): \(value)")
                    }
                }
            }
            print("   Body: \(request.httpBody?.count ?? 0) bytes")
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    lastError = DeviceOAuthError.invalidResponse
                    continue
                }
                
                if (200...299).contains(httpResponse.statusCode) {
                    // Parse OAuth 1.0a response (format: oauth_token=xxx&oauth_token_secret=yyy&oauth_callback_confirmed=true)
                    let responseString = String(data: data, encoding: .utf8) ?? ""
                    let params = OAuth1Helper.parseOAuthResponse(responseString)
                    
                    guard let requestToken = params["oauth_token"],
                          let requestTokenSecret = params["oauth_token_secret"] else {
                        print("❌ Missing oauth_token or oauth_token_secret in response")
                        print("   Response: \(responseString)")
                        lastError = DeviceOAuthError.requestTokenFailed
                        continue
                    }
                    
                    print("✅ Request token received from: \(endpointString)")
                    return (requestToken, requestTokenSecret)
                } else {
                    let errorData = String(data: data, encoding: .utf8) ?? "Unable to decode error"
                    print("❌ Garmin request token error (status \(httpResponse.statusCode)) from \(endpointString):")
                    
                    // Try to extract the actual error message from HTML
                    if let messageRange = errorData.range(of: #"<b>Message</b> ([^<]+)"#, options: .regularExpression) {
                        let nsRange = NSRange(messageRange, in: errorData)
                        if let regex = try? NSRegularExpression(pattern: #"<b>Message</b> ([^<]+)"#, options: []),
                           let match = regex.firstMatch(in: errorData, options: [], range: nsRange),
                           match.numberOfRanges > 1 {
                            let messageRange = Range(match.range(at: 1), in: errorData)!
                            let message = String(errorData[messageRange])
                            print("   Error Message: \(message)")
                        }
                    } else {
                        print("   \(errorData.prefix(500))")
                    }
                    
                    // Log full response for debugging
                    print("   Full Response: \(errorData)")
                    lastError = DeviceOAuthError.requestTokenFailed
                    // Try next endpoint if this one fails
                    continue
                }
            } catch {
                print("❌ Error with endpoint \(endpointString): \(error)")
                lastError = error
                continue
            }
        }
        
        // If we get here, all endpoints failed
        throw lastError ?? DeviceOAuthError.requestTokenFailed
    }
    
    /// Step 2: Authorize the request token and exchange for access token
    private func authorizeGarminToken(
        requestToken: String,
        requestTokenSecret: String,
        consumerKey: String,
        consumerSecret: String,
        from viewController: UIViewController
    ) async throws -> (accessToken: String, accessTokenSecret: String) {
        // Build authorization URL - try connectapi.garmin.com first
        var authURLComponents = URLComponents(string: "https://connectapi.garmin.com/oauth-service/oauth/authorize")!
        authURLComponents.queryItems = [
            URLQueryItem(name: "oauth_token", value: requestToken)
        ]
        
        guard let authURL = authURLComponents.url else {
            throw DeviceOAuthError.invalidURL
        }
        
        print("🔐 Garmin Authorization URL: \(authURL.absoluteString)")
        
        // Create presentation context provider
        let presentationProvider = AuthPresentationContextProvider(viewController: viewController)
        
        // Open authorization page in Safari
        return try await withCheckedThrowingContinuation { continuation in
            let authSession = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: "app.hyka.com"  // Intercept callback
            ) { callbackURL, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let callbackURL = callbackURL else {
                    continuation.resume(throwing: DeviceOAuthError.invalidCallback)
                    return
                }
                
                print("🔗 Garmin OAuth callback received: \(callbackURL.absoluteString)")
                
                // Parse OAuth 1.0a callback (format: app.hyka.com://garmin/callback?oauth_token=xxx&oauth_verifier=yyy)
                guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                      let queryItems = components.queryItems else {
                    continuation.resume(throwing: DeviceOAuthError.invalidCallback)
                    return
                }
                
                // Extract oauth_token and oauth_verifier from callback
                var params: [String: String] = [:]
                for item in queryItems {
                    params[item.name] = item.value
                }
                
                guard let authorizedToken = params["oauth_token"],
                      let verifier = params["oauth_verifier"] else {
                    print("❌ Missing oauth_token or oauth_verifier in callback")
                    print("   Callback: \(callbackURL.absoluteString)")
                    continuation.resume(throwing: DeviceOAuthError.invalidCallback)
                    return
                }
                
                // Verify the token matches
                guard authorizedToken == requestToken else {
                    print("❌ Request token mismatch")
                    continuation.resume(throwing: DeviceOAuthError.invalidCallback)
                    return
                }
                
                print("✅ Authorization callback validated")
                print("   Token: \(authorizedToken.prefix(20))...")
                print("   Verifier: \(verifier.prefix(20))...")
                
                // Step 3: Exchange authorized token for access token
                Task {
                    do {
                        let (accessToken, accessTokenSecret) = try await self.exchangeGarminAccessToken(
                            requestToken: requestToken,
                            requestTokenSecret: requestTokenSecret,
                            verifier: verifier,
                            consumerKey: consumerKey,
                            consumerSecret: consumerSecret
                        )
                        continuation.resume(returning: (accessToken, accessTokenSecret))
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
            
            authSession.presentationContextProvider = presentationProvider
            authSession.prefersEphemeralWebBrowserSession = false
            authSession.start()
            
            // Keep references to prevent deallocation
            objc_setAssociatedObject(viewController, "garminAuthSession", authSession, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            objc_setAssociatedObject(viewController, "authPresentationProvider", presentationProvider, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    /// Step 3: Exchange authorized request token for access token
    private func exchangeGarminAccessToken(
        requestToken: String,
        requestTokenSecret: String,
        verifier: String,
        consumerKey: String,
        consumerSecret: String
    ) async throws -> (accessToken: String, accessTokenSecret: String) {
        // Garmin OAuth 1.0a endpoint - use connectapi.garmin.com (API domain)
        let accessTokenEndpoints = [
            "https://connectapi.garmin.com/oauth-service/oauth/access_token"
        ]
        
        var lastError: Error?
        for endpointString in accessTokenEndpoints {
            guard let accessTokenURL = URL(string: endpointString) else { continue }
            
            // OAuth 1.0a parameters
            var parameters: [String: String] = [:]
            parameters["oauth_verifier"] = verifier
            
            // Generate OAuth 1.0a authorization header
            let authHeader = OAuth1Helper.generateAuthorizationHeader(
                consumerKey: consumerKey,
                consumerSecret: consumerSecret,
                token: requestToken,
                tokenSecret: requestTokenSecret,
                method: "POST",
                url: accessTokenURL,
                parameters: parameters
            )
            
            print("🔐 Exchanging Garmin access token...")
            print("   URL: \(accessTokenURL.absoluteString)")
            
            var request = URLRequest(url: accessTokenURL)
            request.httpMethod = "POST"
            request.setValue(authHeader, forHTTPHeaderField: "Authorization")
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    lastError = DeviceOAuthError.invalidResponse
                    continue
                }
                
                if (200...299).contains(httpResponse.statusCode) {
                    // Parse OAuth 1.0a response
                    let responseString = String(data: data, encoding: .utf8) ?? ""
                    let params = OAuth1Helper.parseOAuthResponse(responseString)
                    
                    guard let accessToken = params["oauth_token"],
                          let accessTokenSecret = params["oauth_token_secret"] else {
                        print("❌ Missing oauth_token or oauth_token_secret in response")
                        print("   Response: \(responseString)")
                        lastError = DeviceOAuthError.tokenExchangeFailed
                        continue
                    }
                    
                    print("✅ Access token received from: \(endpointString)")
                    return (accessToken, accessTokenSecret)
                } else {
                    let errorData = String(data: data, encoding: .utf8) ?? "Unable to decode error"
                    print("❌ Garmin access token exchange error (status \(httpResponse.statusCode)) from \(endpointString):")
                    print("   \(errorData.prefix(500))")
                    lastError = DeviceOAuthError.tokenExchangeFailed
                    // Try next endpoint if this one fails
                    continue
                }
            } catch {
                print("❌ Error with endpoint \(endpointString): \(error)")
                lastError = error
                continue
            }
        }
        
        // If we get here, all endpoints failed
        throw lastError ?? DeviceOAuthError.tokenExchangeFailed
    }

    // MARK: - PKCE Helpers (for Polar OAuth 2.0)
    
    private func generateCodeVerifier() -> String {
        let characters = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        let length = 64
        var result = ""
        result.reserveCapacity(length)
        for _ in 0..<length {
            if let random = characters.randomElement() {
                result.append(random)
            }
        }
        return result
    }
    
    private func generateCodeChallenge(from verifier: String) -> String? {
        guard let data = verifier.data(using: .utf8) else { return nil }
        let hashed = SHA256.hash(data: data)
        let challenge = Data(hashed).base64EncodedString()
        return base64URLEncode(challenge)
    }
    
    private func base64URLEncode(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
    
    private func generateRandomState() -> String {
        let characters = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        let length = 32
        var result = ""
        result.reserveCapacity(length)
        for _ in 0..<length {
            if let random = characters.randomElement() {
                result.append(random)
            }
        }
        return result
    }
    
    private func performPolarOAuth(from viewController: UIViewController) async throws -> (accessToken: String, refreshToken: String?, expiresAt: Date?) {
        // Polar OAuth 2.0
        let polarClientId = Config.polarClientID
        let redirectURI = Config.polarRedirectURI
        
        print("🔄 Polar OAuth 2.0 Flow")
        print("   Client ID: \(polarClientId)")
        print("   Redirect URI: \(redirectURI)")
        
        // Polar OAuth authorization endpoint
        // Reference: https://www.polar.com/accesslink-api/#polar-accesslink-api
        var authURLComponents = URLComponents(string: "https://flow.polar.com/oauth2/authorization")!
        authURLComponents.queryItems = [
            URLQueryItem(name: "client_id", value: polarClientId),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "accesslink.read_all")
        ]
        
        guard let authURL = authURLComponents.url else {
            throw DeviceOAuthError.invalidURL
        }
        
        print("🔐 Polar Authorization URL: \(authURL.absoluteString)")
        
        // Create presentation context provider
        let presentationProvider = AuthPresentationContextProvider(viewController: viewController)
        
        // Open in Safari/ASWebAuthenticationSession
        let callbackURL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            let authSession = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: "app.hyka.com"
            ) { callbackURL, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let callbackURL = callbackURL else {
                    continuation.resume(throwing: DeviceOAuthError.invalidCallback)
                    return
                }
                
                continuation.resume(returning: callbackURL)
            }
            
            authSession.presentationContextProvider = presentationProvider
            authSession.prefersEphemeralWebBrowserSession = false
            
            if !authSession.start() {
                continuation.resume(throwing: DeviceOAuthError.invalidURL)
            }
            
            // Keep references to prevent deallocation
            objc_setAssociatedObject(viewController, "polarAuthSession", authSession, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            objc_setAssociatedObject(viewController, "polarAuthPresentationProvider", presentationProvider, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        
        print("✅ Received Polar callback: \(callbackURL.absoluteString)")
        
        // Extract authorization code
        guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            print("❌ No 'code' parameter found in Polar callback URL")
            throw DeviceOAuthError.invalidCallback
        }
        
        print("✅ Polar authorization code: \(code.prefix(20))...")
        
        // Exchange code for access token via Supabase Edge Function
        let edgeFunctionURL = URL(string: Config.polarAuthCallbackURL)!
        var request = URLRequest(url: edgeFunctionURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "Authorization")
        
        guard let session = session,
              let userId = session.currentUser?.id else {
            throw DeviceOAuthError.notAuthenticated
        }
        
        let requestBody: [String: Any] = [
            "code": code,
            "redirect_uri": redirectURI,
            "user_id": userId.uuidString
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        print("🔄 Exchanging code for tokens via edge function...")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DeviceOAuthError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Token exchange failed: \(httpResponse.statusCode) - \(errorText)")
            throw DeviceOAuthError.apiError(message: "Token exchange failed: HTTP \(httpResponse.statusCode): \(errorText)")
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw DeviceOAuthError.invalidResponse
        }
        
        guard let accessToken = json["access_token"] as? String else {
            throw DeviceOAuthError.apiError(message: "No access_token in response")
        }
        
        let refreshToken = json["refresh_token"] as? String
        let expiresIn = json["expires_in"] as? Int
        let expiresAt: Date? = expiresIn.map { Date().addingTimeInterval(TimeInterval($0)) }
        
        print("✅ Polar tokens received")
        print("   Access token: \(accessToken.prefix(20))...")
        
        return (accessToken, refreshToken, expiresAt)
    }
    
    private func performSuuntoOAuth(from viewController: UIViewController) async throws -> (accessToken: String, refreshToken: String?, expiresAt: Date?) {
        // Suunto OAuth 2.0 Flow
        // Reference: Suunto API documentation
        let suuntoClientId = Config.suuntoClientID
        let redirectURI = Config.suuntoRedirectURI
        
        print("🔄 Suunto OAuth 2.0 Flow")
        print("   Client ID: \(suuntoClientId)")
        print("   Redirect URI: \(redirectURI)")
        
        // Suunto OAuth authorization endpoint
        // IMPORTANT: Per Suunto docs, the authorize endpoint is on cloudapi-oauth.suunto.com
        // NOT cloudapi.suunto.com - that's only for API calls after auth
        // Reference: https://apizone.suunto.com/how-to-start
        var authURLComponents = URLComponents(string: "https://cloudapi-oauth.suunto.com/oauth/authorize")!
        authURLComponents.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: suuntoClientId),
            URLQueryItem(name: "redirect_uri", value: redirectURI)
            // Note: Don't specify scope - Suunto defaults to "workout" which includes 247 data access
            // Adding custom scopes causes "invalid_scope" error
        ]
        
        guard let authURL = authURLComponents.url else {
            throw DeviceOAuthError.invalidURL
        }
        
        print("🔐 Suunto Authorization URL: \(authURL.absoluteString)")
        print("   Redirect URI: \(redirectURI)")
        print("   ⚠️ IMPORTANT: Check Suunto settings:")
        print("      - Authorization Callback Domain MUST be: gvfhtiljkybbrbxoyqsq.supabase.co")
        print("      - Make sure you clicked 'Save' in Suunto Developer Portal")
        print("      - Wait 1-2 minutes after saving for changes to take effect")
        
        // Create presentation context provider
        let presentationProvider = AuthPresentationContextProvider(viewController: viewController)
        
        // Open in Safari/ASWebAuthenticationSession
        // When using web redirect, Suunto redirects to web URL, edge function redirects to app
        let callbackURL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            // Always use app scheme for callback (edge function redirects to this)
            let callbackScheme = "app.hyka.com"
            
            let authSession = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: callbackScheme
            ) { callbackURL, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let callbackURL = callbackURL else {
                    continuation.resume(throwing: DeviceOAuthError.invalidCallback)
                    return
                }
                
                continuation.resume(returning: callbackURL)
            }
            
            authSession.presentationContextProvider = presentationProvider
            authSession.prefersEphemeralWebBrowserSession = false
            
            if !authSession.start() {
                continuation.resume(throwing: DeviceOAuthError.invalidURL)
            }
            
            // Keep references to prevent deallocation
            objc_setAssociatedObject(viewController, "suuntoAuthSession", authSession, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            objc_setAssociatedObject(viewController, "suuntoAuthPresentationProvider", presentationProvider, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        
        print("✅ Received Suunto callback: \(callbackURL.absoluteString)")
        
        // Extract authorization code (same pattern as Garmin/Strava)
        guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false) else {
            print("❌ Failed to parse callback URL into components")
            throw DeviceOAuthError.invalidCallback
        }
        
        print("📋 Query items: \(components.queryItems?.map { "\($0.name)=\($0.value ?? "nil")" }.joined(separator: "&") ?? "none")")
        
        guard let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            print("❌ No 'code' parameter found in Suunto callback URL")
            print("   Available parameters: \(components.queryItems?.map { $0.name }.joined(separator: ", ") ?? "none")")
            throw DeviceOAuthError.invalidCallback
        }
        
        print("✅ Suunto authorization code: \(code.prefix(20))...")
        
        // Exchange code for access token via Supabase Edge Function
        // This keeps the client_secret secure on the server
        let edgeFunctionURL = URL(string: Config.suuntoAuthCallbackURL)!
        var request = URLRequest(url: edgeFunctionURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "Authorization")
        
        guard let session = session,
              let userId = session.currentUser?.id else {
            throw DeviceOAuthError.notAuthenticated
        }
        
        let requestBody: [String: Any] = [
            "code": code,
            "redirect_uri": redirectURI,
            "user_id": userId.uuidString
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        print("🔄 Exchanging code for tokens via edge function...")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DeviceOAuthError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Token exchange failed: \(httpResponse.statusCode) - \(errorText)")
            throw DeviceOAuthError.apiError(message: "Token exchange failed: HTTP \(httpResponse.statusCode): \(errorText)")
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw DeviceOAuthError.invalidResponse
        }
        
        guard let accessToken = json["access_token"] as? String else {
            throw DeviceOAuthError.apiError(message: "No access_token in response")
        }
        
        let refreshToken = json["refresh_token"] as? String
        let expiresIn = json["expires_in"] as? Int
        let expiresAt: Date? = expiresIn.map { Date().addingTimeInterval(TimeInterval($0)) }
        
        print("✅ Suunto tokens received")
        print("   Access token: \(accessToken.prefix(20))...")
        if let expiresIn = expiresIn {
            print("   Expires in: \(expiresIn) seconds")
        }
        
        return (accessToken, refreshToken, expiresAt)
    }
    
    private func performStravaOAuth(from viewController: UIViewController) async throws -> (accessToken: String, refreshToken: String?, expiresAt: Date?) {
        // Strava OAuth 2.0
        let stravaClientId = Config.stravaClientID
        let redirectURI = Config.stravaRedirectURI
        
        print("🔄 Strava OAuth 2.0 Flow")
        print("   Client ID: \(stravaClientId)")
        print("   Redirect URI: \(redirectURI)")
        
        // Strava OAuth authorization endpoint
        // Reference: https://developers.strava.com/docs/authentication/
        // Use same pattern as Garmin - URLComponents handles encoding properly
        var authURLComponents = URLComponents(string: "https://www.strava.com/oauth/authorize")!
        authURLComponents.queryItems = [
            URLQueryItem(name: "client_id", value: stravaClientId),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "activity:read_all,profile:read_all"),
            URLQueryItem(name: "approval_prompt", value: "force"),
            URLQueryItem(name: "state", value: "strava_oauth")
        ]
        
        guard let authURL = authURLComponents.url else {
            throw DeviceOAuthError.invalidURL
        }
        
        print("🔐 Strava Authorization URL: \(authURL.absoluteString)")
        print("   Redirect URI: \(redirectURI)")
        print("   ⚠️ IMPORTANT: Check Strava settings:")
        print("      - Authorization Callback Domain MUST be: app.hyka.com")
        print("      - Make sure you clicked 'Save' in Strava")
        print("      - Wait 1-2 minutes after saving for changes to take effect")
        
        // Log the exact query string to see how redirect_uri is encoded
        if let query = authURL.query {
            print("   Full query string: \(query)")
            if let redirectParam = query.components(separatedBy: "&").first(where: { $0.hasPrefix("redirect_uri=") }) {
                print("   redirect_uri in query: \(redirectParam)")
            }
        }
        
        // Create presentation context provider
        let presentationProvider = AuthPresentationContextProvider(viewController: viewController)
        
        // Open in Safari/ASWebAuthenticationSession
        // When using web redirect, Strava redirects to web URL, edge function redirects to app
        // So we still use the app scheme for the callback
        let callbackURL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            // Always use app scheme for callback (edge function redirects to this)
            let callbackScheme = "app.hyka.com"
            
            let authSession = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: callbackScheme
            ) { callbackURL, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let callbackURL = callbackURL else {
                    continuation.resume(throwing: DeviceOAuthError.invalidCallback)
                    return
                }
                
                continuation.resume(returning: callbackURL)
            }
            
            authSession.presentationContextProvider = presentationProvider
            authSession.prefersEphemeralWebBrowserSession = false
            
            if !authSession.start() {
                continuation.resume(throwing: DeviceOAuthError.invalidURL)
            }
            
            // Keep references to prevent deallocation
            objc_setAssociatedObject(viewController, "stravaAuthSession", authSession, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            objc_setAssociatedObject(viewController, "stravaAuthPresentationProvider", presentationProvider, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        
        print("✅ Received Strava callback: \(callbackURL.absoluteString)")
        
        // Extract authorization code (same pattern as Garmin)
        guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false) else {
            print("❌ Failed to parse callback URL into components")
            throw DeviceOAuthError.invalidCallback
        }
        
        print("📋 Query items: \(components.queryItems?.map { "\($0.name)=\($0.value ?? "nil")" }.joined(separator: "&") ?? "none")")
        
        guard let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            print("❌ No 'code' parameter found in Strava callback URL")
            print("   Available parameters: \(components.queryItems?.map { $0.name }.joined(separator: ", ") ?? "none")")
            throw DeviceOAuthError.invalidCallback
        }
        
        print("✅ Strava authorization code: \(code.prefix(20))...")
        
        // Exchange code for access token via Supabase Edge Function
        // This keeps the client_secret secure on the server
        let edgeFunctionURL = URL(string: Config.stravaAuthCallbackURL)!
        var request = URLRequest(url: edgeFunctionURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add Supabase anon key for authentication
        let supabaseAnonKey = Config.supabaseAnonKey
        request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        
        // Get user's Supabase user ID
        let userId: String
        do {
            let session = try await Supa.client.auth.session
            userId = session.user.id.uuidString
            print("🔑 Using user's Supabase user ID: \(userId)")
        } catch {
            print("❌ Could not get user session")
            throw DeviceOAuthError.tokenExchangeFailed
        }
        
        // Request body with code, redirect_uri, and user_id
        let requestBody: [String: Any] = [
            "code": code,
            "redirect_uri": redirectURI,
            "user_id": userId
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        print("📤 Exchanging Strava code via edge function...")
        print("   URL: \(edgeFunctionURL.absoluteString)")
        print("   User ID: \(userId)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ Strava token exchange: Invalid response type")
            throw DeviceOAuthError.tokenExchangeFailed
        }
        
        print("📡 Strava token exchange response:")
        print("   Status Code: \(httpResponse.statusCode)")
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorData = String(data: data, encoding: .utf8) ?? "Unable to decode error response"
            print("❌ Strava token exchange error (status \(httpResponse.statusCode)):")
            print("   Response: \(errorData)")
            throw DeviceOAuthError.tokenExchangeFailed
        }
        
        // Parse JSON response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accessToken = json["access_token"] as? String else {
            print("❌ Failed to parse Strava token response")
            let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode"
            print("   Response: \(responseString)")
            throw DeviceOAuthError.tokenExchangeFailed
        }
        
        let refreshToken = json["refresh_token"] as? String
        let expiresAt: Date?
        
        if let expiresAtTimestamp = json["expires_at"] as? Int {
            // Strava provides expires_at as Unix timestamp
            expiresAt = Date(timeIntervalSince1970: TimeInterval(expiresAtTimestamp))
        } else {
            expiresAt = nil
        }
        
        print("✅ Strava tokens received")
        print("   Access token: \(accessToken.prefix(20))...")
        if let expiresAt = expiresAt {
            print("   Expires at: \(expiresAt)")
        }
        
        return (accessToken, refreshToken, expiresAt)
    }
    
    // MARK: - Fetch Initial Data
    
    private func fetchAndStoreInitialData(userId: UUID, provider: String, accessToken: String, tokenSecret: String?) async throws {
        print("🔄 Fetching initial data for \(provider)")
        
        let service = WorkoutDataFetchingService()
        // Fetch last 30 days of workouts on initial connection
        // This matches the sync function behavior and ensures users get their historical data
        do {
            let workoutsFetched = try await service.fetchAndStoreWorkouts(
                userId: userId,
                provider: provider,
                accessToken: accessToken,
                tokenSecret: tokenSecret, // OAuth 1.0a token secret (not used for OAuth 2.0)
                after: nil, // Use incremental sync - only fetch new activities
                useIncrementalSync: true
            )
            
            print("✅ Initial data fetch complete for \(provider): \(workoutsFetched) workouts fetched")
        } catch {
            print("❌ Error fetching initial data for \(provider): \(error)")
            // Re-throw to let caller handle the error
            throw error
        }
    }
    
    private func fetchAndStoreHealthMetrics(userId: UUID, provider: String, accessToken: String) async throws {
        print("🔄 Fetching health metrics for \(provider) - pushing to database immediately")
        
        // Fetch last 30 days of health metrics and push to database immediately
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -30, to: endDate) ?? endDate
        
        let service = WorkoutDataFetchingService()
        try await service.fetchAndStoreHealthMetrics(
            userId: userId,
            provider: provider,
            accessToken: accessToken,
            startDate: startDate,
            endDate: endDate
        )
        
        print("✅ Health metrics pushed to database for \(provider)")
    }
    
    private func fetchAndStoreTraining(userId: UUID, provider: String, accessToken: String) async throws {
        print("🔄 Fetching training data for \(provider) - pushing to database immediately")
        
        // Fetch next 30 days of training plans and scheduled workouts
        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: 30, to: startDate) ?? startDate
        
        let service = WorkoutDataFetchingService()
        _ = try await service.fetchAndStoreTraining(
            userId: userId,
            provider: provider,
            accessToken: accessToken,
            startDate: startDate,
            endDate: endDate
        )
        
        print("✅ Training data pushed to database for \(provider)")
    }
    
    /// Trigger historical backfill for last 30 days
    /// This is called automatically when user connects their account
    private func triggerHistoricalSync(userId: UUID, provider: String) async throws {
        print("🔄 Triggering \(provider) historical backfill (last 30 days)...")
        
        guard let session = session else {
            throw DeviceOAuthError.notAuthenticated
        }
        
        // Get Supabase URL and anon key from config
        let supabaseUrl = Config.supabaseURL
        let supabaseAnonKey = Config.supabaseAnonKey
        
        // Get user's Supabase JWT token for authentication
        let supabaseJWT: String
        do {
            let supabaseSession = try await Supa.client.auth.session
            supabaseJWT = supabaseSession.accessToken
        } catch {
            print("⚠️ Could not get Supabase session, using anon key")
            supabaseJWT = supabaseAnonKey
        }
        
        // Call the historical sync edge function
        let functionName = "\(provider)-historical-sync"
        let syncUrl = URL(string: "\(supabaseUrl)/functions/v1/\(functionName)")!
        var request = URLRequest(url: syncUrl)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(supabaseJWT)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        
        let requestBody: [String: Any] = [
            "user_id": userId.uuidString
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        print("📡 Calling \(functionName) edge function...")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DeviceOAuthError.invalidResponse
        }
        
        if (200...299).contains(httpResponse.statusCode) {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let success = json["success"] as? Bool, success {
                print("✅ Historical sync requested successfully for \(provider)")
                if let message = json["message"] as? String {
                    print("   \(message)")
                }
                if let count = json["count"] as? Int {
                    print("   Processed: \(count)")
                }
            } else {
                print("⚠️ Historical sync response received but format unexpected")
            }
        } else {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("⚠️ Historical sync request returned status \(httpResponse.statusCode): \(errorString)")
            // Don't throw - this is a background operation
        }
    }
}

// MARK: - Supporting Types

struct GarminTokenResponse: Codable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int?
    let tokenType: String?
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
    }
}

enum DeviceOAuthError: Error, LocalizedError {
    case notAuthenticated
    case invalidURL
    case invalidCallback
    case invalidResponse
    case requestTokenFailed
    case tokenExchangeFailed
    case apiError(message: String)
    case notImplemented(String)
    case unknownProvider(String)
    case cloudflareBlocked
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User must be authenticated first"
        case .invalidURL:
            return "Invalid OAuth URL"
        case .invalidCallback:
            return "Invalid OAuth callback"
        case .invalidResponse:
            return "Invalid OAuth response from server"
        case .requestTokenFailed:
            return "Failed to obtain request token from Garmin"
        case .tokenExchangeFailed:
            return "Failed to exchange authorization code for access token"
        case .apiError(let message):
            return "API Error: \(message)"
        case .notImplemented(let provider):
            return "\(provider) OAuth not yet implemented"
        case .unknownProvider(let provider):
            return "Unknown provider: \(provider)"
        case .cloudflareBlocked:
            return "Cloudflare security check is blocking the OAuth flow. Please try again, and if you see a Cloudflare challenge in the browser, complete it manually."
        }
    }
}

// MARK: - Presentation Context Provider

/// Helper class to provide presentation context for ASWebAuthenticationSession
final class AuthPresentationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    weak var viewController: UIViewController?
    
    init(viewController: UIViewController) {
        self.viewController = viewController
    }
    
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        if let window = viewController?.view.window {
            return window
        }
        
        // Fallback to key window
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
            return window
        }
        
        // Last resort - create a temporary window with window scene
        // This should rarely be needed since we check for window earlier
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            return UIWindow(windowScene: windowScene)
        }
        
        // Final fallback - only for iOS 14 and below
        // iOS 15+ should always have a window scene available
        if #available(iOS 15.0, *) {
            // iOS 15+ requires window scene - if we get here, something is wrong
            fatalError("Unable to create presentation anchor - no window scene available")
        } else {
            // iOS 14 and below - use deprecated initializer as last resort
            return UIWindow(frame: UIScreen.main.bounds)
        }
    }
}

