import SwiftUI

struct OnboardingStepProfileDetailsView: View {
    @Binding var userProfile: UserProfile
    let onNext: () -> Void
    let onBack: () -> Void
    
    @EnvironmentObject var session: SessionManager
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var birthDate: Date? = nil
    @State private var showDatePicker = false
    @State private var showSignOutAlert = false
    @State private var isSigningOut = false

    var body: some View {
        VStack(spacing: 0) {
            OnboardingProgress(currentStep: 1, totalSteps: 8, showSignOut: true) {
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
                        
                        Text("We'll use this to personalize your experience")
                            .font(HYKATheme.body)
                            .foregroundColor(HYKATheme.Light.mutedForeground)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, HYKATheme.spacingXXL)
                    .padding(.top, HYKATheme.spacingXXL)
                    .padding(.bottom, HYKATheme.spacingL)
                    
                    VStack(spacing: HYKATheme.spacingL) {
                        // First name
                        VStack(alignment: .leading, spacing: HYKATheme.spacingS) {
                            Text("First name")
                                .font(HYKATheme.label)
                                .foregroundColor(HYKATheme.Light.foreground)
                            
                            TextField("First name", text: $firstName)
                                .font(HYKATheme.input)
                                .foregroundColor(HYKATheme.Light.foreground)
                                .padding(.horizontal, HYKATheme.spacingM)
                                .padding(.vertical, HYKATheme.spacingM)
                                .frame(height: 48)
                                .background(HYKATheme.Light.inputBackground)
                                .cornerRadius(HYKATheme.radiusMD)
                                .overlay(
                                    RoundedRectangle(cornerRadius: HYKATheme.radiusMD)
                                        .stroke(HYKATheme.Light.border, lineWidth: 1)
                                )
                        }
                        
                        // Last name
                        VStack(alignment: .leading, spacing: HYKATheme.spacingS) {
                            Text("Last name")
                                .font(HYKATheme.label)
                                .foregroundColor(HYKATheme.Light.foreground)
                            
                            TextField("Last name", text: $lastName)
                                .font(HYKATheme.input)
                                .foregroundColor(HYKATheme.Light.foreground)
                                .padding(.horizontal, HYKATheme.spacingM)
                                .padding(.vertical, HYKATheme.spacingM)
                                .frame(height: 48)
                                .background(HYKATheme.Light.inputBackground)
                                .cornerRadius(HYKATheme.radiusMD)
                                .overlay(
                                    RoundedRectangle(cornerRadius: HYKATheme.radiusMD)
                                        .stroke(HYKATheme.Light.border, lineWidth: 1)
                                )
                        }
                        
                        // Birthdate
                        VStack(alignment: .leading, spacing: HYKATheme.spacingS) {
                            Text("Birthdate")
                                .font(HYKATheme.label)
                                .foregroundColor(HYKATheme.Light.foreground)
                            
                            Button(action: {
                                showDatePicker = true
                            }) {
                                HStack {
                                    Image(systemName: "calendar")
                                        .font(.system(size: 14))
                                        .foregroundColor(HYKATheme.Light.mutedForeground)
                                    
                                    Text(birthDate != nil ? formatDate(birthDate!) : "Choose your birthdate")
                                        .font(HYKATheme.input)
                                        .foregroundColor(birthDate != nil ? HYKATheme.Light.foreground : HYKATheme.Light.mutedForeground)
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, HYKATheme.spacingM)
                                .padding(.vertical, HYKATheme.spacingM)
                                .frame(height: 48)
                                .background(HYKATheme.Light.inputBackground)
                                .cornerRadius(HYKATheme.radiusMD)
                                .overlay(
                                    RoundedRectangle(cornerRadius: HYKATheme.radiusMD)
                                        .stroke(HYKATheme.Light.border, lineWidth: 1)
                                )
                            }
                            
                            Text("Your profile is private by default. Choose what to share later.")
                                .font(HYKATheme.footnote)
                                .foregroundColor(HYKATheme.Light.mutedForeground)
                        }
                        
                        // Continue button
                        Button(action: {
                            if !firstName.isEmpty && !lastName.isEmpty && birthDate != nil {
                                userProfile.firstName = firstName
                                userProfile.lastName = lastName
                                userProfile.birthDate = birthDate ?? Date()
                                onNext()
                            }
                        }) {
                            Text("Continue")
                                .font(HYKATheme.button)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(Color.hykaPurple)
                                .cornerRadius(HYKATheme.radiusMD)
                        }
                        .disabled(firstName.isEmpty || lastName.isEmpty || birthDate == nil)
                        .opacity((firstName.isEmpty || lastName.isEmpty || birthDate == nil) ? 0.5 : 1.0)
                    }
                    .padding(.horizontal, HYKATheme.spacingXXL)
                    .padding(.top, HYKATheme.spacingL)
                }
            }
            .dismissKeyboardOnTap()
        }
        .background(HYKATheme.Light.background)
        .sheet(isPresented: $showDatePicker) {
            NavigationView {
                DatePicker(
                    "Birthdate",
                    selection: Binding(
                        get: { birthDate ?? Date() },
                        set: { birthDate = $0 }
                    ),
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .navigationTitle("Birthdate")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showDatePicker = false
                        }
                        .foregroundColor(.hykaPurple)
                    }
                }
            }
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
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }
}

#Preview {
    OnboardingStepProfileDetailsView(
        userProfile: .constant(UserProfile()),
        onNext: {},
        onBack: {}
    )
}
