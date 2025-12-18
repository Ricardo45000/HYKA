import SwiftUI

struct RunningProfileView: View {
    @Binding var userProfile: UserProfile
    let onNext: () -> Void
    let onBack: () -> Void
    
    @EnvironmentObject var session: SessionManager
    @State private var selectedDistances: Set<UserProfile.RunningDistance> = []
    @State private var selectedExperienceLevel: UserProfile.ExperienceLevel?
    @State private var showSignOutAlert = false
    @State private var isSigningOut = false
    @State private var customDistanceInput: String = ""
    @FocusState private var customDistanceFocused: Bool
    
    private var canContinue: Bool {
        guard !selectedDistances.isEmpty, selectedExperienceLevel != nil else {
            return false
        }
        
        if selectedDistances.contains(.other) {
            return !customDistanceInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        
        return true
    }
    
    var body: some View {
        VStack(spacing: 0) {
            OnboardingProgress(currentStep: 3, totalSteps: 8, showSignOut: true) {
                showSignOutAlert = true
            }
            .environmentObject(session)
            
            ScrollView {
                VStack(spacing: HYKATheme.spacingXXL) {
                    VStack(spacing: HYKATheme.spacingS) {
                        Text("Your running profile")
                            .font(HYKATheme.h2)
                            .foregroundColor(HYKATheme.Light.foreground)
                            .multilineTextAlignment(.center)
                        
                        Text("Help us personalize your pacing and nutrition strategies")
                            .font(HYKATheme.body)
                            .foregroundColor(HYKATheme.Light.mutedForeground)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, HYKATheme.spacingXXL)
                    .padding(.top, HYKATheme.spacingXXL)
                    .padding(.bottom, HYKATheme.spacingL)
                    
                    VStack(alignment: .leading, spacing: HYKATheme.spacingXXL) {
                    // Distances Section
                    VStack(alignment: .leading, spacing: HYKATheme.spacingL) {
                        Text("Which distances do you run?")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(HYKATheme.Light.foreground)
                        
                        // Grid layout: 3 rows with 2 options each, Other standalone
                        VStack(spacing: HYKATheme.spacingM) {
                            // First row: 2 buttons
                            HStack(spacing: HYKATheme.spacingM) {
                                ForEach([UserProfile.RunningDistance.twentyK, .fiftyK], id: \.self) { distance in
                                    DistanceButton(
                                        distance: distance,
                                        isSelected: selectedDistances.contains(distance),
                                        action: {
                                            if selectedDistances.contains(distance) {
                                                selectedDistances.remove(distance)
                                            } else {
                                                selectedDistances.insert(distance)
                                            }
                                        }
                                    )
                                }
                            }
                            
                            // Second row: 2 buttons
                            HStack(spacing: HYKATheme.spacingM) {
                                ForEach([UserProfile.RunningDistance.fiftyM, .hundredK], id: \.self) { distance in
                                    DistanceButton(
                                        distance: distance,
                                        isSelected: selectedDistances.contains(distance),
                                        action: {
                                            if selectedDistances.contains(distance) {
                                                selectedDistances.remove(distance)
                                            } else {
                                                selectedDistances.insert(distance)
                                            }
                                        }
                                    )
                                }
                            }
                            
                            // Third row: 2 buttons
                            HStack(spacing: HYKATheme.spacingM) {
                                ForEach([UserProfile.RunningDistance.hundredM, .multiDay], id: \.self) { distance in
                                    DistanceButton(
                                        distance: distance,
                                        isSelected: selectedDistances.contains(distance),
                                        action: {
                                            if selectedDistances.contains(distance) {
                                                selectedDistances.remove(distance)
                                            } else {
                                                selectedDistances.insert(distance)
                                            }
                                        }
                                    )
                                }
                            }
                            
                            // Other - standalone on bottom
                            DistanceButton(
                                distance: .other,
                                isSelected: selectedDistances.contains(.other),
                                action: {
                                    if selectedDistances.contains(.other) {
                                        selectedDistances.remove(.other)
                                    } else {
                                        selectedDistances.insert(.other)
                                    }
                                }
                            )
                        }
                        
                        if selectedDistances.contains(.other) {
                            VStack(alignment: .leading, spacing: HYKATheme.spacingXS) {
                                Text("Custom distance")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(HYKATheme.Light.mutedForeground)
                                
                                HYKAUIInput(
                                    placeholder: "e.g., 120K mountain ultra",
                                    text: $customDistanceInput,
                                    keyboardType: .default, // Keep default since it might be text (e.g. "120K")
                                    textContentType: .none
                                )
                                .focused($customDistanceFocused)
                            }
                            .transition(.opacity)
                        }
                    }
                    
                    HYKAUISeparator()
                    
                    // Experience Level Section
                    VStack(alignment: .leading, spacing: HYKATheme.spacingL) {
                        Text("Experience level")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(HYKATheme.Light.foreground)
                        
                        VStack(spacing: HYKATheme.spacingM) {
                            ForEach(UserProfile.ExperienceLevel.allCases, id: \.self) { level in
                                Button(action: {
                                    selectedExperienceLevel = level
                                }) {
                                    VStack(alignment: .leading, spacing: HYKATheme.spacingXS) {
                                        Text(level.rawValue)
                                            .font(.system(size: 17, weight: .semibold))
                                            .foregroundColor(HYKATheme.Light.foreground)
                                        
                                        Text(level.description)
                                            .font(.system(size: 14, weight: .regular))
                                            .foregroundColor(HYKATheme.Light.mutedForeground)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(HYKATheme.spacingL)
                                    .background(
                                        RoundedRectangle(cornerRadius: HYKATheme.cornerRadiusM)
                                            .fill(selectedExperienceLevel == level ? Color.hykaPurple.opacity(0.05) : HYKATheme.Light.inputBackground)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: HYKATheme.cornerRadiusM)
                                            .stroke(selectedExperienceLevel == level ? Color.hykaPurple : HYKATheme.Light.border, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    }
                    .padding(.horizontal, HYKATheme.spacingXXL)
                
                Spacer(minLength: HYKATheme.spacingXXL)
                
                // Buttons - consistent design with other steps
                VStack(spacing: HYKATheme.spacingM) {
                    HYKAButton(
                        title: "Continue",
                        style: .primary,
                        action: {
                            customDistanceFocused = false
                            userProfile.runningDistances = Array(selectedDistances)
                            if let level = selectedExperienceLevel {
                                userProfile.experienceLevel = level
                            }
                            if selectedDistances.contains(.other) {
                                userProfile.customDistance = customDistanceInput.trimmingCharacters(in: .whitespacesAndNewlines)
                            } else {
                                userProfile.customDistance = ""
                            }
                            onNext()
                        }
                    )
                    .disabled(!canContinue)
                    
                    HYKAButton(
                        title: "Back",
                        style: .outline,
                        action: onBack
                    )
                }
                .padding(.horizontal, HYKATheme.spacingXXL)
                .padding(.bottom, HYKATheme.spacingXXL)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .keyboardDoneToolbar()
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
        .onAppear {
            selectedDistances = Set(userProfile.runningDistances)
            selectedExperienceLevel = userProfile.experienceLevel
            customDistanceInput = userProfile.customDistance
        }
    }
    
    private func handleSignOut() async {
        isSigningOut = true
        await session.signOut()
        isSigningOut = false
    }
}

// MARK: - Distance Button Component

struct DistanceButton: View {
    let distance: UserProfile.RunningDistance
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: HYKATheme.spacingS) {
                Image(systemName: distance.icon)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? Color.hykaPurple : HYKATheme.Light.mutedForeground)
                
                Text(distance.rawValue)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(isSelected ? Color.hykaPurple : HYKATheme.Light.foreground)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(
                RoundedRectangle(cornerRadius: HYKATheme.cornerRadiusM)
                    .fill(isSelected ? Color.hykaPurple.opacity(0.05) : HYKATheme.Light.inputBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: HYKATheme.cornerRadiusM)
                    .stroke(isSelected ? Color.hykaPurple : HYKATheme.Light.border, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    RunningProfileView(
        userProfile: .constant(UserProfile()),
        onNext: {},
        onBack: {}
    )
}
