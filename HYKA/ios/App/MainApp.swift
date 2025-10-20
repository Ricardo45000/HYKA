import SwiftUI
import Combine
import UIKit

@main
struct HYKAApp: App {
    @StateObject var session = SessionManager()
    @State private var showSplash = true
    @State private var splashOpacity: Double = 1.0
    @State private var splashScale: CGFloat = 1.0
    @State private var pendingURL: URL? = nil
    
    init() {
        // Log on app initialization
        print("")
        print("═══════════════════════════════════════")
        print("🚀 HYKAApp INITIALIZED")
        print("   Deep link handlers should be attached")
        print("═══════════════════════════════════════")
        print("")
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                // Back layer: Main app content
                ContentView()
                    .environmentObject(session)
                    .opacity(showSplash ? 0 : 1)
                    .withErrorDisplay()
                    // Add handler here too as backup
                    .onOpenURL { url in
                        print("")
                        print("🟡🟡🟡 ContentView.onOpenURL FIRED 🟡🟡🟡")
                        print("   URL: \(url)")
                        print("")
                        handleDeepLink(url)
                    }

                if showSplash {
                    SplashView()
                        .scaleEffect(splashScale)
                        .opacity(splashOpacity)
                }
            }
            .preferredColorScheme(.dark)
            .globalKeyboardDismiss()
            .keyboardDoneToolbar()
            .onAppear {
                print("")
                print("═══════════════════════════════════════")
                print("✅ APP APPEARED - Checking for pending deep link")
                print("   Pending URL: \(pendingURL?.absoluteString ?? "nil")")
                print("═══════════════════════════════════════")
                print("")
                
                // Process any pending URL that came while app was launching
                if let url = pendingURL {
                    print("📱 Processing pending deep link that arrived during launch")
                    // Delay slightly to ensure session is initialized
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        handleDeepLink(url)
                        pendingURL = nil
                    }
                }
                
                // Splash shows immediately, no black frame.
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                    withAnimation(.easeOut(duration: 0.4)) {
                        splashOpacity = 0.0
                        splashScale = 1.05
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        showSplash = false
                        
                        // Process any pending URL after splash finishes
                        if let url = pendingURL {
                            print("📱 Processing pending deep link after splash finished")
                            handleDeepLink(url)
                            pendingURL = nil
                        }
                    }
                }
                
                // Log on app appear to verify handler is attached
                print("")
                print("═══════════════════════════════════════")
                print("✅ App appeared - onOpenURL handler should be active")
                print("═══════════════════════════════════════")
                print("")
            }
            .onOpenURL { url in
                // CRITICAL: This MUST fire when deep link is received
                print("")
                print("═══════════════════════════════════════")
                print("🔴🔴🔴 WindowGroup.onOpenURL - HANDLER FIRED!")
                print("🔴🔴🔴 PRIMARY deep link handler")
                print("   URL: \(url)")
                print("   Absolute String: \(url.absoluteString)")
                print("   Scheme: \(url.scheme ?? "nil")")
                print("   Host: \(url.host ?? "nil")")
                print("   App State: showSplash=\(showSplash)")
                print("   Session Loading: \(session.isLoading)")
                print("═══════════════════════════════════════")
                print("")
                
                // Store for later processing if app is launching
                if showSplash {
                    print("⏳ App launching, storing URL AND processing now")
                    pendingURL = url
                }
                
                // ALWAYS process immediately - don't wait
                print("🔄 Processing deep link immediately...")
                handleDeepLink(url)
            }
        }
    }
    
    // Centralized deep link handler
    private func handleDeepLink(_ url: URL) {
        print("")
        print("═══════════════════════════════════════")
        print("🔗 URL OPENED EVENT TRIGGERED")
        print("   Full URL: \(url)")
        print("   Absolute String: \(url.absoluteString)")
        print("   Scheme: \(url.scheme ?? "nil")")
        print("   Host: \(url.host ?? "nil")")
        print("   Path: \(url.path)")
        print("   Query: \(url.query ?? "nil")")
        print("   Fragment: \(url.fragment ?? "nil")")
        print("═══════════════════════════════════════")
        print("")
        
        // Handle OAuth callback deep links - support both custom scheme and Universal Links
        let scheme = url.scheme ?? ""
        let host = url.host ?? ""
        let path = url.path
        
        print("🔍 Checking URL against OAuth pattern...")
        print("   Scheme: \(scheme)")
        print("   Host: \(host)")
        print("   Path: \(path)")
        
        // Check for custom scheme (com.hyka.app://) or Universal Link (https://hyka.app)
        let isCustomScheme = scheme == "com.hyka.app"
        let isUniversalLink = scheme == "https" && host == "hyka.app" && path.hasPrefix("/garmin/callback")
        
        if isCustomScheme || isUniversalLink {
            let absoluteString = url.absoluteString.lowercased()
            let isCallback: Bool
            
            if isUniversalLink {
                // Universal Link: https://hyka.app/garmin/callback?code=...&state=...
                isCallback = path.hasPrefix("/garmin/callback")
                print("   ✅ Universal Link detected: \(isCallback ? "MATCH" : "NO MATCH")")
            } else {
                // Custom scheme: com.hyka.app://callback or com.hyka.app://garmin/callback or com.hyka.app://polar/callback
                isCallback = host == "callback" || 
                            host == "garmin" ||
                            host == "polar" ||
                            host == "" || 
                            absoluteString.contains("callback") ||
                            path.contains("callback")
                print("   ✅ Custom scheme detected: \(isCallback ? "MATCH" : "NO MATCH")")
            }
            
            if isCallback {
                print("")
                print("═══════════════════════════════════════")
                print("🔗 DEEP LINK CALLBACK RECEIVED!")
                print("   URL: \(url)")
                print("   Absolute String: \(url.absoluteString)")
                print("   Type: \(isUniversalLink ? "Universal Link" : "Custom Scheme")")
                print("   This means OAuth completed successfully!")
                print("═══════════════════════════════════════")
                print("")
                Task { @MainActor in
                    await session.handleOAuthCallback(url: url)
                }
            } else {
                print("⚠️  URL has correct scheme but doesn't appear to be callback")
                print("   Full URL: \(url.absoluteString)")
            }
        } else {
            print("⚠️  URL opened but doesn't match OAuth callback pattern")
            print("   Expected: com.hyka.app:// or https://hyka.app/garmin/callback")
            print("   Got: \(scheme)://\(host)\(path)")
            print("   Full URL: \(url.absoluteString)")
        }
    }
}
