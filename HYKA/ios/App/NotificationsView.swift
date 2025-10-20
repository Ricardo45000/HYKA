import SwiftUI

struct NotificationsView: View {
    @State private var notificationsEnabled = false
    
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
                            
                            Toggle("", isOn: $notificationsEnabled)
                                .tint(Color.hykaPurple)
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
                Text("Notification settings will be available soon. We'll notify you when new features are ready.")
                    .font(HYKATheme.caption)
                    .foregroundColor(HYKATheme.Light.mutedForeground)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, HYKATheme.spacingXXL)
            }
            .padding(.vertical, HYKATheme.spacingXXL)
        }
        .background(HYKATheme.backgroundColor)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.light, for: .navigationBar)
    }
}

#Preview {
    NavigationView {
        NotificationsView()
    }
}

