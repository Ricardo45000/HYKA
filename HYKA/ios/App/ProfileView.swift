import SwiftUI
import UIKit
import Auth

struct ProfileView: View {
    @EnvironmentObject var session: SessionManager
    @State private var showSignOutAlert = false
    @State private var isSigningOut = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: HYKATheme.spacingXXL) {
                    // User Info Section
                    VStack(spacing: HYKATheme.spacingL) {
                        // Avatar
                        ZStack {
                            Circle()
                                .fill(Color.hykaPurple.opacity(0.1))
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "person.fill")
                                .font(.system(size: 34))
                                .foregroundColor(Color.hykaPurple)
                        }
                        
                        // User details
                        VStack(spacing: HYKATheme.spacingS) {
                            Text(session.currentUser?.email ?? "User")
                                .font(HYKATheme.h3)
                                .foregroundColor(HYKATheme.Light.foreground)
                            
                            if let userId = session.currentUser?.id.uuidString.prefix(8) {
                                Text("ID: \(userId)")
                                    .font(HYKATheme.caption)
                                    .foregroundColor(HYKATheme.Light.mutedForeground)
                            }
                        }
                    }
                    .padding(.top, HYKATheme.spacingS) // Reduced by 50% (from spacingL)
                    
                    // Settings Section
                    VStack(spacing: 0) {
                        // Account Section
                        VStack(alignment: .leading, spacing: HYKATheme.spacingM) {
                            Text("Account")
                                .font(HYKATheme.label)
                                .foregroundColor(HYKATheme.Light.mutedForeground)
                                .padding(.horizontal, HYKATheme.spacingXXL)
                            
                            VStack(spacing: 0) {
                                NavigationLink(destination: ProfileInformationView()) {
                                    HStack(spacing: HYKATheme.spacingL) {
                                        Image(systemName: "person.circle")
                                            .font(.system(size: 17))
                                            .foregroundColor(Color.hykaPurple)
                                            .frame(width: 24)
                                        
                                        Text("Profile Information")
                                            .font(HYKATheme.body)
                                            .foregroundColor(HYKATheme.Light.foreground)
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(HYKATheme.Light.mutedForeground)
                                    }
                                    .padding(.horizontal, HYKATheme.spacingXXL)
                                    .padding(.vertical, HYKATheme.spacingL)
                                    .background(HYKATheme.Light.card)
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                Divider()
                                    .padding(.leading, HYKATheme.spacingXXL + 36)
                                
                                NavigationLink(destination: NotificationsView()) {
                                    HStack(spacing: HYKATheme.spacingL) {
                                        Image(systemName: "bell")
                                            .font(.system(size: 17))
                                            .foregroundColor(Color.hykaPurple)
                                            .frame(width: 24)
                                        
                                        Text("Notifications")
                                            .font(HYKATheme.body)
                                            .foregroundColor(HYKATheme.Light.foreground)
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(HYKATheme.Light.mutedForeground)
                                    }
                                    .padding(.horizontal, HYKATheme.spacingXXL)
                                    .padding(.vertical, HYKATheme.spacingL)
                                    .background(HYKATheme.Light.card)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            .background(HYKATheme.Light.card)
                            .cornerRadius(HYKATheme.cornerRadiusL)
                        }
                        
                        // App Section
                        VStack(alignment: .leading, spacing: HYKATheme.spacingM) {
                            Text("App")
                                .font(HYKATheme.label)
                                .foregroundColor(HYKATheme.Light.mutedForeground)
                                .padding(.horizontal, HYKATheme.spacingXXL)
                            
                            VStack(spacing: 0) {
                                NavigationLink(destination: WearableConnectionsPageView()) {
                                    HStack(spacing: HYKATheme.spacingL) {
                                        Image(systemName: "link")
                                            .font(.system(size: 17))
                                            .foregroundColor(Color.hykaPurple)
                                            .frame(width: 24)
                                        
                                        Text("Connexion with your wearable")
                                            .font(HYKATheme.body)
                                            .foregroundColor(HYKATheme.Light.foreground)
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(HYKATheme.Light.mutedForeground)
                                    }
                                    .padding(.horizontal, HYKATheme.spacingXXL)
                                    .padding(.vertical, HYKATheme.spacingL)
                                    .background(HYKATheme.Light.card)
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                Divider()
                                    .padding(.leading, HYKATheme.spacingXXL + 36)
                                
                                NavigationLink(destination: TermsOfServiceView()) {
                                    HStack(spacing: HYKATheme.spacingL) {
                                        Image(systemName: "doc.text")
                                            .font(.system(size: 17))
                                            .foregroundColor(Color.hykaPurple)
                                            .frame(width: 24)
                                        
                                        Text("Terms of Service")
                                            .font(HYKATheme.body)
                                            .foregroundColor(HYKATheme.Light.foreground)
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(HYKATheme.Light.mutedForeground)
                                    }
                                    .padding(.horizontal, HYKATheme.spacingXXL)
                                    .padding(.vertical, HYKATheme.spacingL)
                                    .background(HYKATheme.Light.card)
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                Divider()
                                    .padding(.leading, HYKATheme.spacingXXL + 36)
                                
                                NavigationLink(destination: PrivacyPolicyView()) {
                                    HStack(spacing: HYKATheme.spacingL) {
                                        Image(systemName: "lock.shield")
                                            .font(.system(size: 17))
                                            .foregroundColor(Color.hykaPurple)
                                            .frame(width: 24)
                                        
                                        Text("Privacy Policy")
                                            .font(HYKATheme.body)
                                            .foregroundColor(HYKATheme.Light.foreground)
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(HYKATheme.Light.mutedForeground)
                                    }
                                    .padding(.horizontal, HYKATheme.spacingXXL)
                                    .padding(.vertical, HYKATheme.spacingL)
                                    .background(HYKATheme.Light.card)
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                Divider()
                                    .padding(.leading, HYKATheme.spacingXXL + 36)
                                
                                NavigationLink(destination: AboutView()) {
                                    HStack(spacing: HYKATheme.spacingL) {
                                        Image(systemName: "info.circle")
                                            .font(.system(size: 17))
                                            .foregroundColor(Color.hykaPurple)
                                            .frame(width: 24)
                                        
                                        Text("About")
                                            .font(HYKATheme.body)
                                            .foregroundColor(HYKATheme.Light.foreground)
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(HYKATheme.Light.mutedForeground)
                                    }
                                    .padding(.horizontal, HYKATheme.spacingXXL)
                                    .padding(.vertical, HYKATheme.spacingL)
                                    .background(HYKATheme.Light.card)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            .background(HYKATheme.Light.card)
                            .cornerRadius(HYKATheme.cornerRadiusL)
                        }
                        .padding(.top, HYKATheme.spacingL) // Reduced by 50% (from spacingXL)
                    }
                    .padding(.horizontal, HYKATheme.spacingXXL)
                    
                    // Sign Out Button
                    Button {
                        showSignOutAlert = true
                    } label: {
                        HStack(spacing: HYKATheme.spacingM) {
                            if isSigningOut {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .red))
                            } else {
                                Image(systemName: "arrow.right.square")
                                    .font(.system(size: 17))
                                
                                Text("Sign Out")
                                    .font(HYKATheme.button)
                            }
                        }
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.red.opacity(0.05))
                        .cornerRadius(HYKATheme.cornerRadiusM)
                        .overlay(
                            RoundedRectangle(cornerRadius: HYKATheme.cornerRadiusM)
                                .stroke(Color.red.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .disabled(isSigningOut)
                    .padding(.horizontal, HYKATheme.spacingXXL)
                    .padding(.top, HYKATheme.spacingL) // Reduced by 50% (from spacingXL)
                    
                    // App Version
                    Text("HYKA v1.0.0")
                        .font(HYKATheme.caption)
                        .foregroundColor(HYKATheme.Light.mutedForeground)
                        .padding(.top, HYKATheme.spacingL)
                        .padding(.bottom, HYKATheme.spacingXXL)
                }
            }
            .background(HYKATheme.backgroundColor)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.light, for: .navigationBar)
            .onAppear {
                // Set navigation bar title color to black using appearance proxy
                let appearance = UINavigationBarAppearance()
                appearance.configureWithDefaultBackground()
                appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.black]
                appearance.titleTextAttributes = [.foregroundColor: UIColor.black]
                
                UINavigationBar.appearance().standardAppearance = appearance
                UINavigationBar.appearance().scrollEdgeAppearance = appearance
                UINavigationBar.appearance().compactAppearance = appearance
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
    }
    
    private func handleSignOut() async {
        isSigningOut = true
        await session.signOut()
        isSigningOut = false
    }
}

// MARK: - Settings Row Component

struct SettingsRow: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: HYKATheme.spacingL) {
                Image(systemName: icon)
                    .font(.system(size: 17))
                    .foregroundColor(Color.hykaPurple)
                    .frame(width: 24)
                
                Text(title)
                    .font(HYKATheme.body)
                    .foregroundColor(HYKATheme.Light.foreground)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(HYKATheme.Light.mutedForeground)
            }
            .padding(.horizontal, HYKATheme.spacingXXL)
            .padding(.vertical, HYKATheme.spacingL)
            .background(HYKATheme.Light.card)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ProfileView()
        .environmentObject(SessionManager())
}

