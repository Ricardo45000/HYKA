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
                                .foregroundColor(.black) // Typed text in black
                                .textInputAutocapitalization(.words)
                                .autocorrectionDisabled()
                                .submitLabel(.next)
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
                                .foregroundColor(.black) // Typed text in black
                                .textInputAutocapitalization(.words)
                                .autocorrectionDisabled()
                                .submitLabel(.done)
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
                        HYKAButton(
                            title: "Continue",
                            style: .primary,
                            action: {
                                if !firstName.isEmpty && !lastName.isEmpty && birthDate != nil {
                                    userProfile.firstName = firstName
                                    userProfile.lastName = lastName
                                    userProfile.birthDate = birthDate ?? Date()
                                    onNext()
                                }
                            }
                        )
                        .disabled(firstName.isEmpty || lastName.isEmpty || birthDate == nil)
                    }
                    .padding(.horizontal, HYKATheme.spacingXXL)
                    .padding(.top, HYKATheme.spacingL)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .dismissKeyboardOnTap()
        }
        .background(HYKATheme.Light.background)
        .keyboardDoneToolbar()
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
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            showDatePicker = false
                        }
                        .foregroundColor(.hykaPurple)
                    }
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
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
            // Pre-fill from userProfile (which may have been populated from OAuth)
            if firstName.isEmpty && !userProfile.firstName.isEmpty {
                firstName = userProfile.firstName
            }
            if lastName.isEmpty && !userProfile.lastName.isEmpty {
                lastName = userProfile.lastName
            }
            // Note: Birthdate is not provided by OAuth providers, so we don't pre-fill it
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
