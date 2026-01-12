import SwiftUI
import UIKit

struct MainTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            RacePlanView()
                .tabItem { 
                    Label("Races", systemImage: "flag.checkered")
                }
                .tag(0)
            
            ProfileView()
                .tabItem { 
                    Label("Profile", systemImage: "person.circle")
                }
                .tag(1)
        }
        // Note: keyboardDoneToolbar is applied at root level (MainApp) to avoid duplicate "Done" buttons
        .onAppear {
            configureTabBar()
        }
        .onChange(of: selectedTab) { _, _ in
            configureTabBar()
        }
    }
    
    private func configureTabBar() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0) // Light grey background
        
        // Normal state - black icons and text
        appearance.stackedLayoutAppearance.normal.iconColor = .black
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.black,
            .font: UIFont.systemFont(ofSize: 10, weight: .medium)
        ]
        
        // Selected state - purple icons and text
        let purpleColor = UIColor(red: 0.63, green: 0.0, blue: 1.0, alpha: 1.0) // #A020F0
        appearance.stackedLayoutAppearance.selected.iconColor = purpleColor
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: purpleColor,
            .font: UIFont.systemFont(ofSize: 10, weight: .medium)
        ]
        
        // Apply to both standard and scroll edge appearances
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        
        // Also set the unselectedItemTintColor directly
        UITabBar.appearance().unselectedItemTintColor = .black
    }
}

