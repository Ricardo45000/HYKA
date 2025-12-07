import SwiftUI

struct NotificationsView: View {
    @StateObject private var pushService = PushNotificationService.shared
    @State private var notificationsEnabled = false
    @State private var showingSettingsAlert = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: HYKATheme.spacingXXL) {
                // Notifications Toggle Section
                VStack(alignment: .leading, spacing: HYKATheme.spacingM) {
                    Text("Notifications")
                        .font(HYKATheme.label)
                        .foregroundColor(HYKATheme.Light.mutedForeground)
                        .padding(.horizontal, HYKATheme.spacingXXL)
                    
                    VStack(spacing: 0) {
                        HStack {
                            VStack(alignment: .leading, spacing: HYKATheme.spacingXS) {
                                Text("Enable Notifications")
                                    .font(HYKATheme.body)
                                    .foregroundColor(HYKATheme.Light.foreground)
                                
                                Text("Receive push notifications for important updates")
                                    .font(HYKATheme.caption)
                                    .foregroundColor(HYKATheme.Light.mutedForeground)
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: Binding(
                                get: { pushService.isAuthorized },
                                set: { newValue in
                                    if newValue {
                                        Task {
                                            await pushService.requestAuthorization()
                                        }
                                    } else {
                                        // Apps cannot revoke permissions programmatically
                                        showingSettingsAlert = true
                                    }
                                }
                            ))
                            .tint(Color.hykaPurple)
                            .labelsHidden()
                            .scaleEffect(1.2)
                        }
                        .padding(.horizontal, HYKATheme.spacingXXL)
                        .padding(.vertical, HYKATheme.spacingL)
                    }
                    .background(HYKATheme.Light.card)
                    .cornerRadius(HYKATheme.cornerRadiusL)
                }
                .padding(.horizontal, HYKATheme.spacingXXL)
                .padding(.top, HYKATheme.spacingXXL)
                
                // Info Text
                if !pushService.isAuthorized {
                    Text("Tap to enable notifications. You may be prompted to allow notifications in your system settings.")
                        .font(HYKATheme.caption)
                        .foregroundColor(HYKATheme.Light.mutedForeground)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, HYKATheme.spacingXXL)
                }
            }
            .padding(.vertical, HYKATheme.spacingXXL)
        }
        .background(HYKATheme.backgroundColor)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.light, for: .navigationBar)
        .alert(isPresented: $showingSettingsAlert) {
            Alert(
                title: Text("Turn off Notifications"),
                message: Text("To disable notifications, please go to Settings > HYKA > Notifications and switch off 'Allow Notifications'."),
                primaryButton: .default(Text("Open Settings")) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                },
                secondaryButton: .cancel()
            )
        }
        .onAppear {
            // Refresh authorization status
            Task {
                await pushService.checkAuthorizationStatus()
            }
            
            // Set navigation bar title color to black
            let appearance = UINavigationBarAppearance()
            appearance.configureWithDefaultBackground()
            appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.black]
            appearance.titleTextAttributes = [.foregroundColor: UIColor.black]
            
            UINavigationBar.appearance().standardAppearance = appearance
            UINavigationBar.appearance().scrollEdgeAppearance = appearance
            UINavigationBar.appearance().compactAppearance = appearance
        }
    }
}

#Preview {
    NavigationView {
        NotificationsView()
    }
}

