import SwiftUI

struct OnboardingStepNutritionPlanView: View {
    let onNext: () -> Void
    let onSkip: () -> Void
    
    @EnvironmentObject var session: SessionManager
    @State private var showLoginModal = false
    @State private var showSignUpModal = false

    var body: some View {
        ZStack {
            // Background gradient (placeholder for image)
            LinearGradient(
                colors: [
                    Color(red: 0.13, green: 0.16, blue: 0.21),
                    Color(red: 0.09, green: 0.11, blue: 0.17)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer().frame(height: 60)
                
                // Main card
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top) {
                        Text("Nutrition Plan")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(Color.gray.opacity(0.8))
                        
                        Spacer()
                        
                        // Food icon
                        ZStack {
                            Circle()
                                .fill(Color.hykaPurple)
                                .frame(width: 32, height: 32)
                            
                            Image(systemName: "fork.knife")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    
                    // Pre-Race section
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Pre-Race")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.black)
                            
                            Text("Light breakfast + hydration")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        Text("-2 hours")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.gray)
                    }
                    
                    // During Race section
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Every 45 min")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.black)
                            
                            Text("Energy gel + 250ml water")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        Text("During race")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.gray)
                    }
                    
                    // Metrics section
                    HStack(spacing: 20) {
                        VStack {
                            Text("Calories/hr")
                                .font(.system(size: 10, weight: .regular))
                                .foregroundColor(.gray)
                            Text("280")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(Color.hykaPurple)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white)
                        )
                        
                        VStack {
                            Text("Hydration")
                                .font(.system(size: 10, weight: .regular))
                                .foregroundColor(.gray)
                            Text("500ml/hr")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(Color.hykaPurple)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white)
                        )
                    }
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
                )
                .frame(maxWidth: 360)
                .padding(.horizontal, 24)
                
                Spacer()
                
                // Bottom CTA section (text only - buttons moved to parent)
                VStack(spacing: 16) {
                    Text("Nutrition planning")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text("Tailored fueling strategies for race day success.")
                        .font(.system(size: 14, weight: .regular))
                        .multilineTextAlignment(.center)
                        .foregroundColor(Color.white.opacity(0.8))
                }
                .frame(maxWidth: 360)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .sheet(isPresented: $showLoginModal) {
            AuthView()
                .environmentObject(session)
                .interactiveDismissDisabled(false)
        }
        .sheet(isPresented: $showSignUpModal) {
            SignUpModal(
                onSuccess: {
                    showSignUpModal = false
                },
                onUserExists: {
                    showSignUpModal = false
                    showLoginModal = true
                }
            )
            .environmentObject(session)
            .interactiveDismissDisabled(false)
        }
        .onChange(of: session.isAuthenticated) { oldValue, newValue in
            // Auto-dismiss login modal when user becomes authenticated
            print("")
            print("═══════════════════════════════════════")
            print("🔔 OnboardingStepNutritionPlanView: .onChange TRIGGERED")
            print("   session.isAuthenticated changed")
            print("   Old value: \(oldValue)")
            print("   New value: \(newValue)")
            print("   showLoginModal: \(showLoginModal)")
            print("═══════════════════════════════════════")
            print("")
            
            if newValue && !oldValue {
                print("✅ OnboardingStepNutritionPlanView: User authenticated, dismissing login modal")
                showLoginModal = false
                print("   Set showLoginModal = false")
            }
        }
    }
}

#Preview {
    OnboardingStepNutritionPlanView(onNext: {}, onSkip: {})
}
