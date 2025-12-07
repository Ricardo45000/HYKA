import SwiftUI
import Auth

struct OnboardingIntroView: View {
    @EnvironmentObject var session: SessionManager
    @State private var currentIntroStep = 1
    @State private var showMainOnboarding = false
    @State private var transitionOpacity: Double = 1.0
    @State private var showLoginModal = false
    @State private var showSignUpModal = false
    
    private let totalIntroSteps = 3
    
    var body: some View {
        ZStack {
            if showMainOnboarding {
                OnboardingFlowView()
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 1.05)),
                        removal: .opacity
                    ))
            } else {
                // Single page with sliding content
                ZStack {
                    // Background gradient - shared across all slides
                    LinearGradient(
                        colors: [
                            Color(red: 0.15, green: 0.15, blue: 0.20),
                            Color(red: 0.10, green: 0.10, blue: 0.15)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                    
                    VStack(spacing: 0) {
                        // Logo at top - stays fixed
                        HStack {
                            Spacer()
                            Image("Logo-transparent")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 120)
                            Spacer()
                        }
                        .padding(.top, 96)
                        .padding(.horizontal, 24)
                        
                        Spacer()
                        
                        // Sliding content area - only text and card
                TabView(selection: $currentIntroStep) {
                            // Step 1: Route Analysis
                            VStack(spacing: 0) {
                                // Card
                                VStack(alignment: .leading, spacing: 16) {
                                    HStack(alignment: .top) {
                                        Text("Route Analysis")
                                            .font(.system(size: 17, weight: .semibold))
                                            .foregroundColor(Color.gray.opacity(0.8))
                                        
                                        Spacer()
                                        
                                        Image(systemName: "mappin.circle")
                                            .font(.system(size: 17, weight: .semibold))
                                            .foregroundColor(Color.hykaPurple)
                                    }
                                    
                                    Divider()
                                    
                                    // Pale purple inner panel
                                    VStack(spacing: 12) {
                                        ZStack {
                                            Circle()
                                                .fill(Color.hykaPurple)
                                                .frame(width: 64, height: 64)
                                            
                                            Image(systemName: "mappin.circle.fill")
                                                .font(.system(size: 24, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                        
                                        Text("GPX File Ready")
                                            .font(.system(size: 17, weight: .semibold))
                                            .foregroundColor(Color.gray.opacity(0.8))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 24)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.hykaPurple.opacity(0.08))
                                    )
                                    
                                    // 3-column stats row
                                    HStack(alignment: .top, spacing: 24) {
                                        VStack {
                                            Text("Distance")
                                                .font(.system(size: 14, weight: .regular))
                                                .foregroundColor(Color.gray.opacity(0.8))
                                            Text("50K")
                                                .font(.system(size: 17, weight: .semibold))
                                                .foregroundColor(Color.hykaPurple)
                                        }
                                        
                                        Spacer()
                                        
                                        VStack {
                                            Text("Elevation")
                                                .font(.system(size: 14, weight: .regular))
                                                .foregroundColor(Color.gray.opacity(0.8))
                                            Text("2,400m")
                                                .font(.system(size: 17, weight: .semibold))
                                                .foregroundColor(Color.hykaPurple)
                                        }
                                        
                                        Spacer()
                                        
                                        VStack {
                                            Text("Difficulty")
                                                .font(.system(size: 14, weight: .regular))
                                                .foregroundColor(Color.gray.opacity(0.8))
                                            Text("Hard")
                                                .font(.system(size: 17, weight: .semibold))
                                                .foregroundColor(Color.hykaPurple)
                                        }
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
                                
                                Spacer().frame(height: 40)
                                
                                // Text
                                VStack(spacing: 16) {
                                    Text("Upload your race route")
                                        .font(.system(size: 19, weight: .semibold))
                                        .foregroundColor(.white)
                                    
                                    Text("Import GPX files and let AI analyze your course.")
                                        .font(.system(size: 14, weight: .regular))
                                        .multilineTextAlignment(.center)
                                        .foregroundColor(Color.white.opacity(0.8))
                                }
                                .frame(maxWidth: 360)
                                .padding(.horizontal, 24)
                            }
                            .tag(1)
                            
                            // Step 2: Pacing Strategy
                            VStack(spacing: 0) {
                                // Card
                                VStack(alignment: .leading, spacing: 16) {
                                    HStack(alignment: .top) {
                                        Text("Pacing Strategy")
                                            .font(.system(size: 17, weight: .semibold))
                                            .foregroundColor(Color.gray.opacity(0.8))
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chart.line.uptrend.xyaxis")
                                            .font(.system(size: 17, weight: .semibold))
                                            .foregroundColor(Color.hykaPurple)
                                    }
                                    
                                    // Strategy options
                                    VStack(spacing: 12) {
                                        ForEach(0..<3, id: \.self) { index in
                                            let strategies = [
                                                ("Start Easy", "8:30-9:00 min/km"),
                                                ("Steady Climb", "9:30-10:00 min/km"),
                                                ("Push the Pace", "8:00-8:30 min/km")
                                            ]
                                            
                                            HStack {
                                                ZStack {
                                                    Circle()
                                                        .fill(index == 0 ? Color.hykaPurple : Color.gray.opacity(0.3))
                                                        .frame(width: 24, height: 24)
                                                    
                                                    Text("\(index + 1)")
                                                        .font(.system(size: 12, weight: .semibold))
                                                        .foregroundColor(index == 0 ? .white : .gray)
                                                }
                                                
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(strategies[index].0)
                                                        .font(.system(size: 14, weight: .semibold))
                                                        .foregroundColor(.black)
                                                    
                                                    Text(strategies[index].1)
                                                        .font(.system(size: 12, weight: .regular))
                                                        .foregroundColor(.gray)
                                                }
                                                
                                                Spacer()
                                            }
                                            .padding(.vertical, 16)
                                            .padding(.horizontal, 16)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(index == 0 ? Color.hykaPurple.opacity(0.1) : Color.clear)
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 12)
                                                            .stroke(index == 0 ? Color.hykaPurple : Color.gray.opacity(0.3), lineWidth: 1)
                                                    )
                                            )
                                        }
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
                                
                                Spacer().frame(height: 40)
                                
                                // Text
                                VStack(spacing: 16) {
                                    Text("Smart pacing strategies")
                                        .font(.system(size: 19, weight: .semibold))
                                        .foregroundColor(.white)
                                    
                                    Text("Personalized recommendations based on elevation and fitness data.")
                                        .font(.system(size: 14, weight: .regular))
                                        .multilineTextAlignment(.center)
                                        .foregroundColor(Color.white.opacity(0.8))
                                }
                                .frame(maxWidth: 360)
                                .padding(.horizontal, 24)
                            }
                    .tag(2)
                            
                            // Step 3: Nutrition Plan
                            VStack(spacing: 0) {
                                // Card
                                VStack(alignment: .leading, spacing: 16) {
                                    HStack(alignment: .top) {
                                        Text("Nutrition Plan")
                                            .font(.system(size: 17, weight: .semibold))
                                            .foregroundColor(Color.gray.opacity(0.8))
                                        
                                        Spacer()
                                        
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
                                
                                Spacer().frame(height: 40)
                                
                                // Text
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
                            }
                    .tag(3)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .opacity(transitionOpacity)
                        
                        Spacer()
                        
                        // Buttons and pager at bottom - stays fixed
                        VStack(spacing: 16) {
                            // Pager indicator
                            HStack(spacing: 8) {
                                ForEach(1...totalIntroSteps, id: \.self) { step in
                                    if step == currentIntroStep {
                                        Capsule()
                                            .fill(Color.white)
                                            .frame(width: 36, height: 8)
                                    } else {
                                        Circle()
                                            .fill(Color.white.opacity(0.4))
                                            .frame(width: 8, height: 8)
                                    }
                                }
                            }
                            .padding(.top, 8)
                            
                            // Buttons based on current step
                            if currentIntroStep < totalIntroSteps {
                                // Primary button
                                Button(action: nextIntroStep) {
                                    Text("Next")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 18)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16)
                                                .fill(Color.hykaPurple)
                                        )
                                }
                                .padding(.top, 16)
                                .padding(.horizontal, 24)
                                
                                // Skip button
                                Button(action: skipToNutritionPlan) {
                                    Text("Skip")
                                        .font(.system(size: 15, weight: .regular))
                                        .foregroundColor(Color.white.opacity(0.8))
                                }
                                .padding(.top, 16)
                            } else {
                                // Last step - show Join/Login buttons
                                Button(action: {
                                    showSignUpModal = true
                                }) {
                                    Text("Join for free")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 18)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16)
                                                .fill(Color.hykaPurple)
                                        )
                                }
                                .padding(.top, 16)
                                .padding(.horizontal, 24)
                                
                                Button(action: {
                                    showLoginModal = true
                                }) {
                                    Text("Log in")
                                        .font(.system(size: 15, weight: .regular))
                                        .foregroundColor(Color.hykaPurple)
                                }
                                .padding(.top, 16)
                            }
                        }
                        .padding(.bottom, 32)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.35), value: showMainOnboarding)
        .animation(.spring(response: 0.4, dampingFraction: 0.85, blendDuration: 0), value: currentIntroStep)
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
            print("🔍 OnboardingIntroView: Authentication state changed - old: \(oldValue), new: \(newValue)")
            // If user becomes authenticated, navigate to main onboarding
            if newValue && !showMainOnboarding {
                print("✅ OnboardingIntroView: User authenticated, navigating to OnboardingFlowView")
                showLoginModal = false
                showSignUpModal = false
                skipToMainOnboarding()
            }
        }
    }
    
    private func nextIntroStep() {
        if currentIntroStep < totalIntroSteps {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85, blendDuration: 0)) {
                currentIntroStep += 1
            }
        } else {
            completeIntro()
        }
    }
    
    private func skipToNutritionPlan() {
        // Jump directly to Nutrition Plan (step 3 - last intro page)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85, blendDuration: 0)) {
            currentIntroStep = 3
        }
    }
    
    private func skipToMainOnboarding() {
        withAnimation(.easeOut(duration: 0.25)) {
            transitionOpacity = 0.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.easeInOut(duration: 0.35)) {
                showMainOnboarding = true
            }
        }
    }
    
    private func completeIntro() {
        withAnimation(.easeOut(duration: 0.25)) {
            transitionOpacity = 0.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.easeInOut(duration: 0.35)) {
                showMainOnboarding = true
            }
        }
    }
}

#Preview {
    OnboardingIntroView()
}
