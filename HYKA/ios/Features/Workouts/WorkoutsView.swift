import SwiftUI
import UIKit
import Auth

struct WearableConnectionsView: View {
    enum DisplayMode {
        case fullScreen
        case section
    }
    
    @EnvironmentObject var session: SessionManager
    @StateObject private var oauthManager: DeviceOAuthManager
    @State private var connectedDevices: Set<String> = []
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    @State private var showDisconnectAlert = false
    @State private var devicePendingDisconnect: String? = nil
    
    private let devices = DeviceConnection.mock
    private let displayMode: DisplayMode
    
    private var headerTitle: String {
        switch displayMode {
        case .fullScreen:
            return "Connect your devices"
        case .section:
            return "Connexion with your wearable"
        }
    }
    
    private var headerSubtitle: String {
        switch displayMode {
        case .fullScreen:
            return "Sync your fitness data to get more accurate pacing and nutrition recommendations"
        case .section:
            return "Link your supported wearables to keep health and training data in sync."
        }
    }
    
    init(displayMode: DisplayMode = .fullScreen) {
        self.displayMode = displayMode
        _oauthManager = StateObject(wrappedValue: DeviceOAuthManager(session: SessionManager()))
    }

    var body: some View {
        baseView
            .onAppear {
                oauthManager.setSession(session)
                Task {
                    await loadExistingConnections()
                }
            }
            .alert("Connection Error", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .alert("Disconnect Device", isPresented: $showDisconnectAlert) {
                Button("Cancel", role: .cancel) {
                    devicePendingDisconnect = nil
                }
                Button("Disconnect", role: .destructive) {
                    if let deviceName = devicePendingDisconnect {
                        Task {
                            await disconnectDevice(deviceName)
                        }
                    }
                }
            } message: {
                if let deviceName = devicePendingDisconnect {
                    Text("Are you sure you want to disconnect \(deviceName) from the app?")
                } else {
                    Text("")
                }
            }
            .overlay {
                if isLoading {
                    loadingOverlay
                }
            }
    }
    
    @ViewBuilder
    private var baseView: some View {
        switch displayMode {
        case .fullScreen:
            ZStack {
                HYKATheme.Light.background
                    .ignoresSafeArea()
                
                ScrollView {
                    content
                        .padding(.horizontal, HYKATheme.spacingXXL)
                        .padding(.top, HYKATheme.spacingS) // Reduced by 50% (from spacingL)
                        .padding(.bottom, HYKATheme.spacingXXL)
                }
            }
        case .section:
            VStack(alignment: .leading, spacing: HYKATheme.spacingXL) {
                content
            }
            .padding(HYKATheme.spacingXL)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: HYKATheme.cornerRadiusL)
                    .fill(HYKATheme.Light.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: HYKATheme.cornerRadiusL)
                    .stroke(HYKATheme.Light.border, lineWidth: 1)
            )
        }
    }
    
    private var content: some View {
        VStack(alignment: .leading, spacing: HYKATheme.spacingXL) {
            header
            selectionHeader
            deviceGrid
            whyConnectSection
        }
    }
    
    private var header: some View {
        VStack(alignment: displayMode == .fullScreen ? .center : .leading, spacing: HYKATheme.spacingS) {
            Text(headerTitle)
                .font(displayMode == .fullScreen ? .system(size: 22, weight: .bold) : HYKATheme.h3)
                .foregroundColor(HYKATheme.Light.foreground)
                .multilineTextAlignment(displayMode == .fullScreen ? .center : .leading)
            
            Text(headerSubtitle)
                .font(displayMode == .fullScreen ? .system(size: 13, weight: .regular) : HYKATheme.body)
                .foregroundColor(HYKATheme.Light.mutedForeground)
                .multilineTextAlignment(displayMode == .fullScreen ? .center : .leading)
        }
        .frame(maxWidth: .infinity, alignment: displayMode == .fullScreen ? .center : .leading)
    }
    
    private var selectionHeader: some View {
        VStack(alignment: .leading, spacing: HYKATheme.spacingS) {
            Text("Select your platforms")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(HYKATheme.Light.foreground)
            
            Text("Tap a platform to connect your account")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(HYKATheme.Light.mutedForeground)
        }
    }
    
    private var deviceGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: HYKATheme.spacingL) {
            ForEach(devices, id: \.name) { device in
                let comingSoon = isComingSoon(device.name)
                
                Button {
                    handleDeviceConnection(device.name)
                } label: {
                    ZStack(alignment: .topTrailing) {
                        VStack(spacing: HYKATheme.spacingS) {
                            ZStack {
                                Circle()
                                    .fill(iconBackgroundColor(for: device.name, isConnected: connectedDevices.contains(device.name)))
                                    .frame(width: 42, height: 42)
                                
                                Image(device.icon)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 24, height: 24)
                            }
                            
                            VStack(spacing: 4) {
                                Text(device.name)
                                    .font(.system(size: 15, weight: .regular))
                                    .foregroundColor(comingSoon ? HYKATheme.Light.mutedForeground : HYKATheme.Light.foreground)
                                
                                if comingSoon {
                                    Text("Coming soon")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(HYKATheme.Light.mutedForeground)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 105)
                        .background(
                            RoundedRectangle(cornerRadius: HYKATheme.cornerRadiusM)
                                .fill(connectedDevices.contains(device.name) ? Color.hykaPurple.opacity(0.1) : HYKATheme.Light.card)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: HYKATheme.cornerRadiusM)
                                .stroke(connectedDevices.contains(device.name) ? Color.hykaPurple : HYKATheme.Light.border, lineWidth: 1)
                        )
                        
                        if connectedDevices.contains(device.name) {
                            ZStack {
                                Circle()
                                    .fill(Color.hykaPurple)
                                    .frame(width: 24, height: 24)
                                
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            .padding(8)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(comingSoon)
                .opacity(comingSoon ? 0.6 : 1.0)
            }
        }
    }
    
    private var whyConnectSection: some View {
        VStack(alignment: .leading, spacing: HYKATheme.spacingM) {
            Text("Why connect?")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Color.hykaPurple)
            
            VStack(alignment: .leading, spacing: HYKATheme.spacingS) {
                bulletPoint(text: "Training history and fitness metrics")
                bulletPoint(text: "VO2 max and performance data")
                bulletPoint(text: "Personalized race strategies")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(HYKATheme.spacingL)
        .background(
            RoundedRectangle(cornerRadius: HYKATheme.cornerRadiusM)
                .fill(Color.hykaPurple.opacity(0.1))
        )
    }
    
    private func bulletPoint(text: String) -> some View {
        HStack(alignment: .top, spacing: HYKATheme.spacingS) {
            Circle()
                .fill(Color.hykaPurple)
                .frame(width: 6, height: 6)
                .padding(.top, 6)
            
            Text(text)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(HYKATheme.Light.foreground)
        }
    }
    
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: HYKATheme.spacingL) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                
                if let provider = oauthManager.connectingProvider {
                    Text("Connecting to \(provider)...")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                } else {
                    Text("Connecting...")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .padding(HYKATheme.spacingXXL)
            .background(
                RoundedRectangle(cornerRadius: HYKATheme.cornerRadiusL)
                    .fill(Color.hykaPurple)
            )
        }
    }
    
    private func iconBackgroundColor(for deviceName: String, isConnected: Bool) -> Color {
        if isComingSoon(deviceName) {
            return HYKATheme.Light.muted.opacity(0.3)
        } else if isConnected {
            return Color.hykaPurple.opacity(0.2)
        } else {
            return HYKATheme.Light.muted.opacity(0.5)
        }
    }
    
    private func handleDeviceConnection(_ deviceName: String) {
        if isComingSoon(deviceName) {
            return
        }
        
        if connectedDevices.contains(deviceName) {
            devicePendingDisconnect = deviceName
            showDisconnectAlert = true
            return
        }
        
        Task {
            isLoading = true
            
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootViewController = windowScene.windows.first?.rootViewController else {
                errorMessage = "Could not find view controller for OAuth"
                showErrorAlert = true
                isLoading = false
                return
            }
            
            do {
                try await oauthManager.connectProvider(deviceName, from: rootViewController)
                connectedDevices.insert(deviceName)
                print("✅ Successfully connected to \(deviceName)")
            } catch {
                if case DeviceOAuthError.notImplemented(let message) = error {
                    errorMessage = "\(deviceName) connection not yet available. \(message)"
                } else {
                    errorMessage = "Failed to connect to \(deviceName): \(error.localizedDescription)"
                }
                showErrorAlert = true
                print("❌ Error connecting to \(deviceName): \(error)")
                ErrorManager.shared.showError(error, title: "Connection Failed")
            }
            
            isLoading = false
        }
    }
    
    private func disconnectDevice(_ deviceName: String) async {
        guard connectedDevices.contains(deviceName) else { return }
        guard let userId = session.currentUser?.id ?? (session.isAuthenticated ? UUID(uuidString: UserDefaults.standard.string(forKey: "hyka.user.id") ?? "") : nil) else {
            return
        }
        
        do {
            try await SupabaseService.deleteOAuthConnection(userId: userId, provider: deviceName.lowercased())
            await MainActor.run {
                connectedDevices.remove(deviceName)
                devicePendingDisconnect = nil
            }
        } catch {
            print("⚠️ Error disconnecting \(deviceName): \(error)")
            await MainActor.run {
                errorMessage = "Failed to disconnect \(deviceName). Please try again."
                showErrorAlert = true
            }
        }
    }
    
    private func isComingSoon(_ deviceName: String) -> Bool {
        deviceName == "Suunto" || deviceName == "Coros"
    }
    
    private func loadExistingConnections() async {
        guard let userId = session.currentUser?.id ?? (session.isAuthenticated ? UUID(uuidString: UserDefaults.standard.string(forKey: "hyka.user.id") ?? "") : nil) else {
            return
        }
        
        do {
            let connections = try await SupabaseService.fetchOAuthConnections(userId: userId)
            let supportedNames = Set(devices.map { $0.name.lowercased() })
            
            var connectedSet: Set<String> = []
            for connection in connections {
                let providerName = connection.provider.lowercased()
                if supportedNames.contains(providerName) {
                    connectedSet.insert(providerName.capitalized)
                }
            }
            
            await MainActor.run {
                connectedDevices = connectedSet
                print("✅ Loaded existing connections: \(connectedSet)")
            }
        } catch {
            print("⚠️ Error loading existing connections: \(error)")
        }
    }
}

#Preview {
    WearableConnectionsView()
        .environmentObject(SessionManager())
}
