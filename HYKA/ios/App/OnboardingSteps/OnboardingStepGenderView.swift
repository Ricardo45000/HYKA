import SwiftUI

struct OnboardingStepGenderView: View {
    @Binding var userProfile: UserProfile
    let onNext: () -> Void
    let onBack: () -> Void
    
    @EnvironmentObject var session: SessionManager
    @State private var selectedGender: String = ""
    @State private var showSignOutAlert = false
    @State private var isSigningOut = false

    var body: some View {
        VStack(spacing: 0) {
            OnboardingProgress(currentStep: 2, totalSteps: 8, showSignOut: true) {
                showSignOutAlert = true
            }
            .environmentObject(session)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(spacing: HYKATheme.spacingS) {
                        Text("Tell us who you are")
                            .font(HYKATheme.h2)
                            .foregroundColor(HYKATheme.Light.foreground)
                            .multilineTextAlignment(.center)
                        
                        Text("Help us personalize your experience")
                            .font(HYKATheme.body)
                            .foregroundColor(HYKATheme.Light.mutedForeground)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, HYKATheme.spacingXXL)
                    .padding(.top, HYKATheme.spacingXXL)
                    .padding(.bottom, HYKATheme.spacingL)
                    
                    VStack(spacing: HYKATheme.spacingM) {
                        let genders = ["Male", "Female", "Non-binary", "Prefer not to say"]
                        
                        ForEach(genders, id: \.self) { gender in
                            Button(action: {
                                selectedGender = gender
                            }) {
                                HStack {
                                    Text(gender)
                                        .font(HYKATheme.body)
                                        .foregroundColor(HYKATheme.Light.foreground)
                                    
                                    Spacer()
                                    
                                    if selectedGender == gender {
                                        ZStack {
                                            Circle()
                                                .fill(Color.hykaPurple)
                                                .frame(width: 20, height: 20)
                                            
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                    }
                                }
                                .padding(.horizontal, HYKATheme.spacingL)
                                .padding(.vertical, HYKATheme.spacingL)
                                .background(
                                    RoundedRectangle(cornerRadius: HYKATheme.radiusLG)
                                        .fill(selectedGender == gender ? Color.hykaPurple.opacity(0.08) : Color.clear)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: HYKATheme.radiusLG)
                                                .stroke(
                                                    selectedGender == gender ? Color.hykaPurple : HYKATheme.Light.border,
                                                    lineWidth: 2
                                                )
                                        )
                                )
                            }
                        }
                        
                        Text("Your profile is private by default. Choose what information is shared later.")
                            .font(HYKATheme.footnote)
                            .foregroundColor(HYKATheme.Light.mutedForeground)
                            .padding(.top, HYKATheme.spacingL)
                    }
                    .padding(.horizontal, HYKATheme.spacingXXL)
                    .padding(.top, HYKATheme.spacingL)
                    
                    HStack(spacing: HYKATheme.spacingM) {
                        Button(action: onBack) {
                            Text("Back")
                                .font(HYKATheme.button)
                                .foregroundColor(HYKATheme.Light.foreground)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(Color.clear)
                                .cornerRadius(HYKATheme.radiusMD)
                                .overlay(
                                    RoundedRectangle(cornerRadius: HYKATheme.radiusMD)
                                        .stroke(HYKATheme.Light.border, lineWidth: 1)
                                )
                        }
                        
                        Button(action: {
                            // Use the exact raw value from the enum
                            if let gender = UserProfile.Gender(rawValue: selectedGender) {
                                userProfile.gender = gender
                                print("✅ Gender selected: \(selectedGender) -> \(gender.rawValue)")
                            } else {
                                // Fallback to prefer not to say if something goes wrong
                                print("⚠️ Failed to match gender '\(selectedGender)', using prefer not to say")
                                userProfile.gender = .preferNotToSay
                            }
                            onNext()
                        }) {
                            Text("Continue")
                                .font(HYKATheme.button)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(Color.hykaPurple)
                                .cornerRadius(HYKATheme.radiusMD)
                        }
                        .disabled(selectedGender.isEmpty)
                        .opacity(selectedGender.isEmpty ? 0.5 : 1.0)
                    }
                    .padding(.horizontal, HYKATheme.spacingXXL)
                    .padding(.top, HYKATheme.spacingXXL)
                    .padding(.bottom, HYKATheme.spacingXXL)
                }
            }
        }
        .background(HYKATheme.Light.background)
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
    OnboardingStepGenderView(
        userProfile: .constant(UserProfile()),
        onNext: {},
        onBack: {}
    )
}
