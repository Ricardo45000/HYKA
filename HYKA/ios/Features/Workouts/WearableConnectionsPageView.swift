import SwiftUI
import Auth

struct WearableConnectionsPageView: View {
    @EnvironmentObject var session: SessionManager
    
    var body: some View {
        WearableConnectionsView(displayMode: .fullScreen)
            .environmentObject(session)
            .navigationTitle("Connexion with your wearable")
            .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    NavigationView {
        WearableConnectionsPageView()
            .environmentObject(SessionManager())
    }
}

