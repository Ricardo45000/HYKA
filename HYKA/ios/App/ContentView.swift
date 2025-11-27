import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject var session: SessionManager
    @StateObject private var networkMonitor = NetworkMonitor.shared
    
    var body: some View {
        let _ = print("🔍 ContentView rendering - isAuthenticated: \(session.isAuthenticated), hasCompletedOnboarding: \(session.hasCompletedOnboarding), isLoading: \(session.isLoading)")
        
        return ZStack {
            if session.isLoading {
                // Loading state while checking session
                Color.hykaPurple
                    .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    
                    Text("Loading...")
                        .font(HYKATheme.body)
                        .foregroundColor(.white)
                }
            } else if session.isAuthenticated && session.hasCompletedOnboarding {
                // Returning user - show main app
                MainTabView()
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 1.05)),
                        removal: .opacity
                    ))
                    .withOfflineAlert()
            } else if session.isAuthenticated && !session.hasCompletedOnboarding {
                // First-time user - show onboarding flow
                OnboardingFlowView()
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 1.05)),
                        removal: .opacity
                    ))
            } else {
                // Not authenticated - show intro + sign in
                OnboardingIntroView()
                    .transition(.asymmetric(
                        insertion: .opacity,
                        removal: .opacity.combined(with: .scale(scale: 0.95))
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.35), value: session.isAuthenticated)
        .animation(.easeInOut(duration: 0.35), value: session.hasCompletedOnboarding)
        .animation(.easeInOut(duration: 0.25), value: session.isLoading)
    }
}
