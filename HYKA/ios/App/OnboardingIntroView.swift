import SwiftUI

struct OnboardingIntroView: View {
    @EnvironmentObject var session: SessionManager
    @State private var currentIntroStep = 1
    @State private var showMainOnboarding = false
    @State private var transitionOpacity: Double = 1.0
    
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
                TabView(selection: $currentIntroStep) {
                    OnboardingStepRouteAnalysisView(
                        onNext: nextIntroStep,
                        onSkip: skipToNutritionPlan
                    )
                    .tag(1)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .trailing)),
                        removal: .opacity.combined(with: .move(edge: .leading))
                    ))
                    
                    OnboardingStepPacingStrategyView(
                        onNext: nextIntroStep,
                        onSkip: skipToNutritionPlan
                    )
                    .tag(2)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .trailing)),
                        removal: .opacity.combined(with: .move(edge: .leading))
                    ))
                    
                    OnboardingStepNutritionPlanView(
                        onNext: completeIntro,
                        onSkip: skipToMainOnboarding
                    )
                    .tag(3)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .trailing)),
                        removal: .opacity.combined(with: .move(edge: .leading))
                    ))
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .opacity(transitionOpacity)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.35), value: showMainOnboarding)
        .animation(.spring(response: 0.4, dampingFraction: 0.85, blendDuration: 0), value: currentIntroStep)
        .onChange(of: session.isAuthenticated) { oldValue, newValue in
            print("🔍 OnboardingIntroView: Authentication state changed - old: \(oldValue), new: \(newValue)")
            // If user becomes authenticated, navigate to main onboarding
            if newValue && !showMainOnboarding {
                print("✅ OnboardingIntroView: User authenticated, navigating to OnboardingFlowView")
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
