import SwiftUI

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: HYKATheme.spacingXXL) {
                // App Logo/Icon
                VStack(spacing: HYKATheme.spacingL) {
                    ZStack {
                        Circle()
                            .fill(Color.hykaPurple.opacity(0.1))
                            .frame(width: 120, height: 120)
                        
                        Image(systemName: "figure.run")
                            .font(.system(size: 60))
                            .foregroundColor(Color.hykaPurple)
                    }
                    
                    Text("HYKA")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(HYKATheme.Light.foreground)
                    
                    Text("v1.0.0")
                        .font(HYKATheme.caption)
                        .foregroundColor(HYKATheme.Light.mutedForeground)
                }
                .padding(.top, HYKATheme.spacingXXL)
                
                // About Section
                VStack(alignment: .leading, spacing: HYKATheme.spacingL) {
                    Text("About HYKA")
                        .font(HYKATheme.h3)
                        .foregroundColor(HYKATheme.Light.foreground)
                    
                    Text("""
                    HYKA is a comprehensive race planning application designed specifically for ultra runners. Our mission is to help athletes prepare, plan, and execute their race strategies with confidence.
                    
                    Whether you're training for your first ultra or preparing for your next big challenge, HYKA provides personalized pacing strategies, nutrition planning, and race day guidance based on your unique profile and race course.
                    """)
                        .font(HYKATheme.body)
                        .foregroundColor(HYKATheme.Light.mutedForeground)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, HYKATheme.spacingXXL)
                
                // Features Section
                VStack(alignment: .leading, spacing: HYKATheme.spacingL) {
                    Text("Key Features")
                        .font(HYKATheme.h3)
                        .foregroundColor(HYKATheme.Light.foreground)
                    
                    VStack(alignment: .leading, spacing: HYKATheme.spacingM) {
                        FeatureRow(icon: "map", title: "Race Planning", description: "Upload GPX files and plan your race strategy")
                        FeatureRow(icon: "figure.run", title: "Personalized Pacing", description: "Get pacing recommendations based on your profile")
                        FeatureRow(icon: "fork.knife", title: "Nutrition Strategy", description: "Plan your fueling strategy for race day")
                        FeatureRow(icon: "link", title: "Device Integration", description: "Connect with Garmin, Polar, Coros, and Suunto")
                        FeatureRow(icon: "cloud.sun", title: "Weather Integration", description: "Get weather forecasts for your race day")
                    }
                }
                .padding(.horizontal, HYKATheme.spacingXXL)
                
                // Contact Section
                VStack(alignment: .leading, spacing: HYKATheme.spacingL) {
                    Text("Contact Us")
                        .font(HYKATheme.h3)
                        .foregroundColor(HYKATheme.Light.foreground)
                    
                    VStack(alignment: .leading, spacing: HYKATheme.spacingS) {
                        Link(destination: URL(string: "https://hyka.app")!) {
                            ContactRow(icon: "globe", text: "https://hyka.app")
                        }
                        Link(destination: URL(string: "mailto:moritz@hyka.app")!) {
                            ContactRow(icon: "envelope", text: "moritz@hyka.app")
                        }
                    }
                }
                .padding(.horizontal, HYKATheme.spacingXXL)
                
                // Copyright
                Text("© 2024 HYKA. All rights reserved.")
                    .font(HYKATheme.caption)
                    .foregroundColor(HYKATheme.Light.mutedForeground)
                    .padding(.top, HYKATheme.spacingL)
                    .padding(.bottom, HYKATheme.spacingXXL)
            }
        }
        .background(HYKATheme.backgroundColor)
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.light, for: .navigationBar)
        .onAppear {
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

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: HYKATheme.spacingM) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(Color.hykaPurple)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: HYKATheme.spacingXS) {
                Text(title)
                    .font(HYKATheme.body)
                    .foregroundColor(HYKATheme.Light.foreground)
                
                Text(description)
                    .font(HYKATheme.caption)
                    .foregroundColor(HYKATheme.Light.mutedForeground)
            }
        }
    }
}

struct ContactRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: HYKATheme.spacingM) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(Color.hykaPurple)
                .frame(width: 20)
            
            Text(text)
                .font(HYKATheme.body)
                .foregroundColor(HYKATheme.Light.mutedForeground)
        }
    }
}

#Preview {
    NavigationView {
        AboutView()
    }
}

