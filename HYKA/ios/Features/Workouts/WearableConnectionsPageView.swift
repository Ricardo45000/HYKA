import SwiftUI
import Auth

struct WearableConnectionsPageView: View {
    @EnvironmentObject var session: SessionManager
    
    var body: some View {
        WearableConnectionsView(displayMode: .fullScreen)
            .environmentObject(session)
            .navigationTitle("Connection with your wearable")
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

#Preview {
    NavigationView {
        WearableConnectionsPageView()
            .environmentObject(SessionManager())
    }
}

