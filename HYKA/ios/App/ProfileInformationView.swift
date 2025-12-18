import SwiftUI
import Auth
import Supabase

struct ProfileInformationView: View {
    @EnvironmentObject var session: SessionManager
    @Environment(\.dismiss) var dismiss
    
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var email: String = ""
    @State private var birthDate: Date = Date()
    @State private var gender: UserProfile.Gender = .preferNotToSay
    
    @State private var currentPassword: String = ""
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var isChangingPassword = false
    @State private var showPasswordChange = false
    @State private var showSuccess = false
    @State private var successMessage = ""
    
    @FocusState private var focusedField: Field?
    
    enum Field {
        case firstName, lastName, email, currentPassword, newPassword, confirmPassword
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: HYKATheme.spacingXXL) {
                // Profile Information Section
                VStack(alignment: .leading, spacing: HYKATheme.spacingM) {
                    Text("Personal Information")
                        .font(HYKATheme.label)
                        .foregroundColor(HYKATheme.Light.mutedForeground)
                        .padding(.horizontal, HYKATheme.spacingXXL)
                    
                    VStack(spacing: 0) {
                        // First Name (read-only)
                        VStack(alignment: .leading, spacing: HYKATheme.spacingXS) {
                            Text("First Name")
                                .font(HYKATheme.caption)
                                .foregroundColor(HYKATheme.Light.mutedForeground)
                            
                            TextField("Enter first name", text: $firstName)
                                .textFieldStyle(HYKATextFieldStyle())
                                .disabled(true)
                                .foregroundColor(HYKATheme.Light.mutedForeground)
                        }
                        .padding(.horizontal, HYKATheme.spacingXXL)
                        .padding(.vertical, HYKATheme.spacingL)
                        
                        Divider()
                            .padding(.leading, HYKATheme.spacingXXL)
                        
                        // Last Name (read-only)
                        VStack(alignment: .leading, spacing: HYKATheme.spacingXS) {
                            Text("Last Name")
                                .font(HYKATheme.caption)
                                .foregroundColor(HYKATheme.Light.mutedForeground)
                            
                            TextField("Enter last name", text: $lastName)
                                .textFieldStyle(HYKATextFieldStyle())
                                .disabled(true)
                                .foregroundColor(HYKATheme.Light.mutedForeground)
                        }
                        .padding(.horizontal, HYKATheme.spacingXXL)
                        .padding(.vertical, HYKATheme.spacingL)
                        
                        Divider()
                            .padding(.leading, HYKATheme.spacingXXL)
                        
                        // Email (read-only)
                        VStack(alignment: .leading, spacing: HYKATheme.spacingXS) {
                            Text("Email")
                                .font(HYKATheme.caption)
                                .foregroundColor(HYKATheme.Light.mutedForeground)
                            
                            TextField("Email", text: $email)
                                .textFieldStyle(HYKATextFieldStyle())
                                .disabled(true)
                                .foregroundColor(HYKATheme.Light.mutedForeground)
                        }
                        .padding(.horizontal, HYKATheme.spacingXXL)
                        .padding(.vertical, HYKATheme.spacingL)
                        
                        Divider()
                            .padding(.leading, HYKATheme.spacingXXL)
                        
                        // Birth Date (read-only)
                        VStack(alignment: .leading, spacing: HYKATheme.spacingXS) {
                            Text("Birth Date")
                                .font(HYKATheme.caption)
                                .foregroundColor(HYKATheme.Light.mutedForeground)
                            
                            // Display birth date as text instead of DatePicker
                            Text(formatDate(birthDate))
                                .font(HYKATheme.body)
                                .foregroundColor(HYKATheme.Light.mutedForeground)
                                .padding(.horizontal, HYKATheme.spacingM)
                                .padding(.vertical, HYKATheme.spacingM)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(HYKATheme.Light.card)
                                .cornerRadius(HYKATheme.cornerRadiusM)
                                .overlay(
                                    RoundedRectangle(cornerRadius: HYKATheme.cornerRadiusM)
                                        .stroke(Color.hykaPurple.opacity(0.2), lineWidth: 1)
                                )
                        }
                        .padding(.horizontal, HYKATheme.spacingXXL)
                        .padding(.vertical, HYKATheme.spacingL)
                        
                        Divider()
                            .padding(.leading, HYKATheme.spacingXXL)
                        
                        // Gender (read-only)
                        VStack(alignment: .leading, spacing: HYKATheme.spacingXS) {
                            Text("Gender")
                                .font(HYKATheme.caption)
                                .foregroundColor(HYKATheme.Light.mutedForeground)
                            
                            // Display gender as text instead of Picker
                            Text(gender.rawValue)
                                .font(HYKATheme.body)
                                .foregroundColor(HYKATheme.Light.mutedForeground)
                                .padding(.horizontal, HYKATheme.spacingM)
                                .padding(.vertical, HYKATheme.spacingM)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(HYKATheme.Light.card)
                                .cornerRadius(HYKATheme.cornerRadiusM)
                                .overlay(
                                    RoundedRectangle(cornerRadius: HYKATheme.cornerRadiusM)
                                        .stroke(Color.hykaPurple.opacity(0.2), lineWidth: 1)
                                )
                        }
                        .padding(.horizontal, HYKATheme.spacingXXL)
                        .padding(.vertical, HYKATheme.spacingL)
                    }
                    .background(HYKATheme.Light.card)
                    .cornerRadius(HYKATheme.cornerRadiusL)
                }
                .padding(.horizontal, HYKATheme.spacingXXL)
                
                // Password Change Section
                VStack(alignment: .leading, spacing: HYKATheme.spacingM) {
                    Text("Password")
                        .font(HYKATheme.label)
                        .foregroundColor(HYKATheme.Light.mutedForeground)
                        .padding(.horizontal, HYKATheme.spacingXXL)
                    
                    VStack(spacing: 0) {
                        if showPasswordChange {
                            // Current Password
                            VStack(alignment: .leading, spacing: HYKATheme.spacingXS) {
                                Text("Current Password")
                                    .font(HYKATheme.caption)
                                    .foregroundColor(HYKATheme.Light.mutedForeground)
                                
                                SecureField("Enter current password", text: $currentPassword)
                                    .textFieldStyle(HYKATextFieldStyle())
                                    .focused($focusedField, equals: .currentPassword)
                            }
                            .padding(.horizontal, HYKATheme.spacingXXL)
                            .padding(.vertical, HYKATheme.spacingL)
                            
                            Divider()
                                .padding(.leading, HYKATheme.spacingXXL)
                            
                            // New Password
                            VStack(alignment: .leading, spacing: HYKATheme.spacingXS) {
                                Text("New Password")
                                    .font(HYKATheme.caption)
                                    .foregroundColor(HYKATheme.Light.mutedForeground)
                                
                                SecureField("Enter new password", text: $newPassword)
                                    .textFieldStyle(HYKATextFieldStyle())
                                    .focused($focusedField, equals: .newPassword)
                            }
                            .padding(.horizontal, HYKATheme.spacingXXL)
                            .padding(.vertical, HYKATheme.spacingL)
                            
                            Divider()
                                .padding(.leading, HYKATheme.spacingXXL)
                            
                            // Confirm Password
                            VStack(alignment: .leading, spacing: HYKATheme.spacingXS) {
                                Text("Confirm New Password")
                                    .font(HYKATheme.caption)
                                    .foregroundColor(HYKATheme.Light.mutedForeground)
                                
                                SecureField("Confirm new password", text: $confirmPassword)
                                    .textFieldStyle(HYKATextFieldStyle())
                                    .focused($focusedField, equals: .confirmPassword)
                            }
                            .padding(.horizontal, HYKATheme.spacingXXL)
                            .padding(.vertical, HYKATheme.spacingL)
                            
                            Divider()
                                .padding(.leading, HYKATheme.spacingXXL)
                            
                            // Cancel Password Change
                            Button {
                                showPasswordChange = false
                                currentPassword = ""
                                newPassword = ""
                                confirmPassword = ""
                            } label: {
                                Text("Cancel Password Change")
                                    .font(HYKATheme.body)
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, HYKATheme.spacingL)
                            }
                            .padding(.horizontal, HYKATheme.spacingXXL)
                            .padding(.vertical, HYKATheme.spacingM)
                        } else {
                            // Change Password Button
                            Button {
                                showPasswordChange = true
                            } label: {
                                HStack {
                                    Image(systemName: "lock.rotation")
                                        .font(.system(size: 17))
                                    Text("Change Password")
                                        .font(HYKATheme.body)
                                }
                                .foregroundColor(Color.hykaPurple)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, HYKATheme.spacingL)
                            }
                            .padding(.horizontal, HYKATheme.spacingXXL)
                            .padding(.vertical, HYKATheme.spacingM)
                        }
                    }
                    .background(HYKATheme.Light.card)
                    .cornerRadius(HYKATheme.cornerRadiusL)
                }
                .padding(.horizontal, HYKATheme.spacingXXL)
                
                // Save Button (only shown when password change is active)
                if showPasswordChange {
                    Button {
                        Task {
                            await savePassword()
                        }
                    } label: {
                        HStack {
                            if isChangingPassword {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Save Password")
                                    .font(HYKATheme.button)
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(isChangingPassword ? Color.gray : Color.hykaPurple)
                        .cornerRadius(HYKATheme.cornerRadiusM)
                    }
                    .disabled(isChangingPassword || isLoading)
                    .padding(.horizontal, HYKATheme.spacingXXL)
                    .padding(.top, HYKATheme.spacingL)
                }
            }
            .padding(.vertical, HYKATheme.spacingXXL)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(HYKATheme.backgroundColor)
        .navigationTitle("Profile Information")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.light, for: .navigationBar)
        .keyboardDoneToolbar()
        .onAppear {
            // Set navigation bar title color to black
            let appearance = UINavigationBarAppearance()
            appearance.configureWithDefaultBackground()
            appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.black]
            appearance.titleTextAttributes = [.foregroundColor: UIColor.black]
            
            UINavigationBar.appearance().standardAppearance = appearance
            UINavigationBar.appearance().scrollEdgeAppearance = appearance
            UINavigationBar.appearance().compactAppearance = appearance
            
            loadProfile()
        }
        .withErrorDisplay()
        .alert("Success", isPresented: $showSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(successMessage)
        }
    }
    
    private func loadProfile() {
        guard let userId = session.currentUser?.id else { return }
        
        isLoading = true
        Task {
            do {
                if let profile = try await SupabaseService.fetchUserProfile(userId: userId) {
                    await MainActor.run {
                        firstName = profile.firstName
                        lastName = profile.lastName
                        birthDate = profile.birthDate
                        gender = profile.gender
                        email = session.currentUser?.email ?? ""
                        isLoading = false
                    }
                } else {
                    await MainActor.run {
                        email = session.currentUser?.email ?? ""
                        isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    ErrorManager.shared.showError(error, title: "Failed to Load Profile")
                    isLoading = false
                }
            }
        }
    }
    
    private func savePassword() async {
        guard let userId = session.currentUser?.id else {
            await MainActor.run {
                ErrorManager.shared.showError(title: "Authentication Required", message: "User not authenticated")
            }
            return
        }
        
        // Validate password change
        guard !currentPassword.isEmpty, !newPassword.isEmpty, !confirmPassword.isEmpty else {
            await MainActor.run {
                ErrorManager.shared.showError(title: "Validation Error", message: "Please fill in all password fields")
            }
            return
        }
        
        guard newPassword == confirmPassword else {
            await MainActor.run {
                ErrorManager.shared.showError(title: "Validation Error", message: "New passwords do not match")
            }
            return
        }
        
        guard newPassword.count >= 6 else {
            await MainActor.run {
                ErrorManager.shared.showError(title: "Validation Error", message: "Password must be at least 6 characters")
            }
            return
        }
        
        // Change password
        isChangingPassword = true
        do {
            // Update password using Supabase Auth
            // First verify current password by attempting to sign in
            let currentEmail = session.currentUser?.email ?? ""
            _ = try await Supa.client.auth.signIn(email: currentEmail, password: currentPassword)
            
            // If sign in succeeds, update password
            try await Supa.client.auth.update(user: UserAttributes(password: newPassword))
            
            await MainActor.run {
                isChangingPassword = false
                showPasswordChange = false
                currentPassword = ""
                newPassword = ""
                confirmPassword = ""
                successMessage = "Password changed successfully"
                showSuccess = true
            }
        } catch {
            await MainActor.run {
                isChangingPassword = false
                if error.localizedDescription.contains("Invalid login credentials") || error.localizedDescription.contains("Email not confirmed") {
                    ErrorManager.shared.showError(title: "Password Change Failed", message: "Current password is incorrect")
                } else {
                    ErrorManager.shared.showError(error, title: "Failed to Change Password")
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Text Field Style

struct HYKATextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .foregroundColor(.black) // Typed text in black
            .padding(HYKATheme.spacingM)
            .background(HYKATheme.Light.card)
            .cornerRadius(HYKATheme.cornerRadiusM)
            .overlay(
                RoundedRectangle(cornerRadius: HYKATheme.cornerRadiusM)
                    .stroke(Color.hykaPurple.opacity(0.2), lineWidth: 1)
            )
    }
}

#Preview {
    NavigationView {
        ProfileInformationView()
            .environmentObject(SessionManager())
    }
}

