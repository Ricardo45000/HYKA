import SwiftUI

struct StrategyPreferencesView: View {
    @Binding var preferences: StrategyPreferences
    let onGenerate: () -> Void
    let onBack: () -> Void
    
    @EnvironmentObject var session: SessionManager
    @State private var selectedGoal: StrategyPreferences.RaceGoal?
    @State private var selectedNutrition: StrategyPreferences.NutritionPreference?
    @State private var showSignOutAlert = false
    @State private var isSigningOut = false
    
    var body: some View {
        VStack(spacing: 0) {
            OnboardingProgress(currentStep: 9, totalSteps: 9, showSignOut: true) {
                showSignOutAlert = true
            }
            .environmentObject(session)
            
            // Custom header with purple dot and Skip button
            HStack {
                HStack(spacing: HYKATheme.spacingM) {
                    Circle()
                        .fill(Color.hykaPurple)
                        .frame(width: 8, height: 8)
                    
                    Text("Strategy Preferences")
                        .font(HYKATheme.label)
                        .foregroundColor(HYKATheme.Light.foreground)
                }
                
                Spacer()
                
                Button(action: {
                    // Skip to generate with current selections
                    onGenerate()
                }) {
                    Text("Skip")
                        .font(HYKATheme.body)
                        .foregroundColor(HYKATheme.Light.mutedForeground)
                }
            }
            .padding(.horizontal, HYKATheme.spacingXXL)
            .padding(.vertical, HYKATheme.spacingL)
            .background(Color.white)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(HYKATheme.Light.border),
                alignment: .bottom
            )
            
            ScrollView {
                VStack(spacing: HYKATheme.spacingXXL) {
                    // Main goal section
                    VStack(alignment: .leading, spacing: HYKATheme.spacingL) {
                        VStack(alignment: .leading, spacing: HYKATheme.spacingS) {
                            Text("What's your main goal?")
                                .font(HYKATheme.h2)
                                .foregroundColor(HYKATheme.Light.foreground)
                            
                            Text("This helps us tailor your pacing strategy")
                                .font(HYKATheme.body)
                                .foregroundColor(HYKATheme.Light.mutedForeground)
                        }
                        
                        VStack(spacing: HYKATheme.spacingM) {
                            ForEach(StrategyPreferences.RaceGoal.allCases, id: \.self) { goal in
                                Button(action: {
                                    selectedGoal = goal
                                }) {
                                    Text(goal.rawValue)
                                        .font(HYKATheme.body)
                                        .foregroundColor(HYKATheme.Light.foreground)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(HYKATheme.spacingL)
                                        .background(
                                            RoundedRectangle(cornerRadius: HYKATheme.cornerRadiusM)
                                                .fill(selectedGoal == goal ? Color.hykaPurple.opacity(0.05) : HYKATheme.Light.card)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: HYKATheme.cornerRadiusM)
                                                .stroke(selectedGoal == goal ? Color.hykaPurple : HYKATheme.Light.border, lineWidth: 1)
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    .padding(.horizontal, HYKATheme.spacingXXL)
                    .padding(.top, HYKATheme.spacingXXL)
                    
                    // Nutrition preference section
                    VStack(alignment: .leading, spacing: HYKATheme.spacingL) {
                        VStack(alignment: .leading, spacing: HYKATheme.spacingS) {
                            Text("Nutrition preference")
                                .font(HYKATheme.h2)
                                .foregroundColor(HYKATheme.Light.foreground)
                            
                            Text("We'll recommend products based on your preference")
                                .font(HYKATheme.body)
                                .foregroundColor(HYKATheme.Light.mutedForeground)
                        }
                        
                        VStack(spacing: HYKATheme.spacingM) {
                            ForEach(StrategyPreferences.NutritionPreference.allCases, id: \.self) { nutrition in
                                Button(action: {
                                    selectedNutrition = nutrition
                                }) {
                                    Text(nutrition.rawValue)
                                        .font(HYKATheme.body)
                                        .foregroundColor(HYKATheme.Light.foreground)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(HYKATheme.spacingL)
                                        .background(
                                            RoundedRectangle(cornerRadius: HYKATheme.cornerRadiusM)
                                                .fill(selectedNutrition == nutrition ? Color.hykaPurple.opacity(0.05) : HYKATheme.Light.card)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: HYKATheme.cornerRadiusM)
                                                .stroke(selectedNutrition == nutrition ? Color.hykaPurple : HYKATheme.Light.border, lineWidth: 1)
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    .padding(.horizontal, HYKATheme.spacingXXL)
                    
                    Spacer(minLength: HYKATheme.spacingXXL)
                    
                    // Generate button
                    HYKAButton(title: "Generate Strategy", style: .primary) {
                        if let goal = selectedGoal {
                            preferences.raceGoals = [goal]
                        }
                        if let nutrition = selectedNutrition {
                            preferences.nutritionPreferences = [nutrition]
                        }
                        onGenerate()
                    }
                    .padding(.horizontal, HYKATheme.spacingXXL)
                    .padding(.bottom, HYKATheme.spacingXXL)
                }
            }
            .background(HYKATheme.backgroundColor)
        }
        .alert("Sign Out", isPresented: $showSignOutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                Task {
                    await handleSignOut()
                }
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }
    
    private func handleSignOut() async {
        isSigningOut = true
        await session.signOut()
        isSigningOut = false
    }
}

#Preview {
    StrategyPreferencesView(preferences: .constant(StrategyPreferences()), onGenerate: {}, onBack: {})
}


