import SwiftUI

struct SignUpProfileView: View {
    @Binding var userProfile: UserProfile
    let onNext: () -> Void
    let onBack: () -> Void
    
    @State private var currentSubStep = 0
    @State private var email = ""
    @State private var password = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var birthDate = Date()
    @State private var selectedGender: UserProfile.Gender = .preferNotToSay
    
    private let subSteps = ["Sign Up", "Tell us who you are", "Gender"]
    
    var body: some View {
        VStack(spacing: HYKATheme.spacingXXL) {
            Spacer()
            
            // Progress indicator
            HStack {
                ForEach(0..<subSteps.count, id: \.self) { index in
                    Circle()
                        .fill(index <= currentSubStep ? HYKATheme.accentColor : HYKATheme.borderColor)
                        .frame(width: 8, height: 8)
                    
                    if index < subSteps.count - 1 {
                        Rectangle()
                            .fill(index < currentSubStep ? HYKATheme.accentColor : HYKATheme.borderColor)
                            .frame(height: 2)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.horizontal, HYKATheme.spacingL)
            
            // Content based on current sub-step
            Group {
                switch currentSubStep {
                case 0:
                    signUpStep
                case 1:
                    profileStep
                case 2:
                    genderStep
                default:
                    EmptyView()
                }
            }
            
            Spacer()
            
            // Buttons
            VStack(spacing: HYKATheme.spacingM) {
                HYKAButton(
                    title: currentSubStep == subSteps.count - 1 ? "Continue" : "Next",
                    style: .primary,
                    action: handleNext
                )
                
                if currentSubStep > 0 {
                    HYKAButton(
                        title: "Back",
                        style: .outline,
                        action: handleBack
                    )
                }
            }
            .padding(.horizontal, HYKATheme.spacingL)
            .padding(.bottom, HYKATheme.spacingXXL)
        }
        .dismissKeyboardOnTap()
    }
    
    private var signUpStep: some View {
        VStack(spacing: HYKATheme.spacingL) {
            HYKACard {
                VStack(spacing: HYKATheme.spacingL) {
                    VStack(alignment: .leading, spacing: HYKATheme.spacingS) {
                        Text("Email")
                            .font(HYKATheme.callout)
                            .foregroundColor(HYKATheme.textPrimary)
                        
                        TextField("Enter your email", text: $email)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .foregroundColor(.black) // Typed text in black
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                    }
                    
                    VStack(alignment: .leading, spacing: HYKATheme.spacingS) {
                        Text("Password")
                            .font(HYKATheme.callout)
                            .foregroundColor(HYKATheme.textPrimary)
                        
                        SecureField("Enter your password", text: $password)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .foregroundColor(.black) // Typed text in black
                    }
                }
            }
            
            VStack(spacing: HYKATheme.spacingM) {
                HYKAButton(
                    title: "Continue with Google",
                    style: .outline,
                    action: {}
                )
                
                HYKAButton(
                    title: "Continue with Facebook",
                    style: .outline,
                    action: {}
                )
            }
        }
        .padding(.horizontal, HYKATheme.spacingL)
    }
    
    private var profileStep: some View {
        VStack(spacing: HYKATheme.spacingL) {
            HYKACard {
                VStack(spacing: HYKATheme.spacingL) {
                    VStack(alignment: .leading, spacing: HYKATheme.spacingS) {
                        Text("First Name")
                            .font(HYKATheme.callout)
                            .foregroundColor(HYKATheme.textPrimary)
                        
                        TextField("Enter your first name", text: $firstName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .foregroundColor(.black) // Typed text in black
                    }
                    
                    VStack(alignment: .leading, spacing: HYKATheme.spacingS) {
                        Text("Last Name")
                            .font(HYKATheme.callout)
                            .foregroundColor(HYKATheme.textPrimary)
                        
                        TextField("Enter your last name", text: $lastName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .foregroundColor(.black) // Typed text in black
                    }
                    
                    VStack(alignment: .leading, spacing: HYKATheme.spacingS) {
                        Text("Birth Date")
                            .font(HYKATheme.callout)
                            .foregroundColor(HYKATheme.textPrimary)
                        
                        DatePicker("", selection: $birthDate, displayedComponents: .date)
                            .datePickerStyle(CompactDatePickerStyle())
                    }
                }
            }
        }
        .padding(.horizontal, HYKATheme.spacingL)
    }
    
    private var genderStep: some View {
        VStack(spacing: HYKATheme.spacingL) {
            HYKACard {
                VStack(spacing: HYKATheme.spacingM) {
                    ForEach(UserProfile.Gender.allCases, id: \.self) { gender in
                        Button(action: {
                            selectedGender = gender
                        }) {
                            HStack {
                                Text(gender.rawValue)
                                    .font(HYKATheme.body)
                                    .foregroundColor(HYKATheme.textPrimary)
                                
                                Spacer()
                                
                                if selectedGender == gender {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(HYKATheme.accentColor)
                                }
                            }
                            .padding(.vertical, HYKATheme.spacingS)
                        }
                        
                        if gender != UserProfile.Gender.allCases.last {
                            Divider()
                                .background(HYKATheme.borderColor)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, HYKATheme.spacingL)
    }
    
    private func handleNext() {
        if currentSubStep < subSteps.count - 1 {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentSubStep += 1
            }
        } else {
            // Save profile data
            userProfile.firstName = firstName
            userProfile.lastName = lastName
            userProfile.birthDate = birthDate
            userProfile.gender = selectedGender
            onNext()
        }
    }
    
    private func handleBack() {
        if currentSubStep > 0 {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentSubStep -= 1
            }
        } else {
            onBack()
        }
    }
}

#Preview {
    SignUpProfileView(
        userProfile: .constant(UserProfile()),
        onNext: {},
        onBack: {}
    )
}
