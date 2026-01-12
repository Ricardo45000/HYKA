import SwiftUI
import UIKit
import Auth

struct ConnectDevicesView: View {
    let onNext: () -> Void
    let onSkip: () -> Void
    let onBack: () -> Void
    
    @EnvironmentObject var session: SessionManager
    @StateObject private var oauthManager: DeviceOAuthManager
    @State private var connectedDevices: Set<String> = []
    @State private var isLoading = false
    @State private var showDisconnectAlert = false
    @State private var devicePendingDisconnect: String? = nil
    @State private var showSignOutAlert = false
    @State private var isSigningOut = false
    
    private let devices = DeviceConnection.mock
    
    init(onNext: @escaping () -> Void, onSkip: @escaping () -> Void, onBack: @escaping () -> Void) {
        self.onNext = onNext
        self.onSkip = onSkip
        self.onBack = onBack
        // Initialize with placeholder - will be set in onAppear
        _oauthManager = StateObject(wrappedValue: DeviceOAuthManager(session: SessionManager()))
    }
    
    private var hasConnectedDevices: Bool {
        !connectedDevices.isEmpty
    }
    
    var body: some View {
        VStack(spacing: 0) {
            OnboardingProgress(currentStep: 4, totalSteps: 8, showSignOut: true) {
                showSignOutAlert = true
            }
            .environmentObject(session)
            
            ScrollView {
                VStack(spacing: HYKATheme.spacingXXL) {
                    VStack(spacing: HYKATheme.spacingS) {
                        Text("Connect your devices")
                            .font(HYKATheme.h2)
                            .foregroundColor(HYKATheme.Light.foreground)
                            .multilineTextAlignment(.center)
                        
                        Text("Sync your fitness data to get more accurate pacing and nutrition recommendations")
                            .font(HYKATheme.body)
                            .foregroundColor(HYKATheme.Light.mutedForeground)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, HYKATheme.spacingXXL)
                    .padding(.top, HYKATheme.spacingXXL)
                    .padding(.bottom, HYKATheme.spacingL)
                    
                    VStack(spacing: HYKATheme.spacingXXL) {
                        // Device Grid
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
                                    // Icon with circular background
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
                                            .font(HYKATheme.body)
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
                                    RoundedRectangle(cornerRadius: HYKATheme.cornerRadiusL)
                                        .fill(connectedDevices.contains(device.name) ? Color.hykaPurple.opacity(0.05) : HYKATheme.Light.card)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: HYKATheme.cornerRadiusL)
                                        .stroke(connectedDevices.contains(device.name) ? Color.hykaPurple : HYKATheme.Light.border, lineWidth: 1)
                                )
                                
                                // Checkmark indicator in top-right corner
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
                .padding(.horizontal, HYKATheme.spacingXXL)
                .padding(.top, HYKATheme.spacingXXL)
                
                // Why connect section
                VStack(alignment: .leading, spacing: HYKATheme.spacingM) {
                    Text("Why connect?")
                        .font(HYKATheme.h4)
                        .foregroundColor(Color.hykaPurple)
                    
                    VStack(alignment: .leading, spacing: HYKATheme.spacingS) {
                        HStack(alignment: .top, spacing: HYKATheme.spacingS) {
                            Text("•")
                                .foregroundColor(Color.hykaPurple)
                            Text("Training history and fitness metrics")
                                .font(HYKATheme.body)
                                .foregroundColor(HYKATheme.Light.foreground)
                        }
                        
                        HStack(alignment: .top, spacing: HYKATheme.spacingS) {
                            Text("•")
                                .foregroundColor(Color.hykaPurple)
                            Text("VO2 max and performance data")
                                .font(HYKATheme.body)
                                .foregroundColor(HYKATheme.Light.foreground)
                        }
                        
                        HStack(alignment: .top, spacing: HYKATheme.spacingS) {
                            Text("•")
                                .foregroundColor(Color.hykaPurple)
                            Text("Personalized race strategies")
                                .font(HYKATheme.body)
                                .foregroundColor(HYKATheme.Light.foreground)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(HYKATheme.spacingL)
                .background(
                    RoundedRectangle(cornerRadius: HYKATheme.cornerRadiusM)
                        .fill(Color.hykaPurple.opacity(0.05))
                )
                .padding(.horizontal, HYKATheme.spacingXXL)
                
                // Strava data coverage info card
                VStack(alignment: .leading, spacing: HYKATheme.spacingS) {
                    Text("Strava provides ~90% of what Garmin or Polar provides for race planning. The main gap is health metrics (weight, VO2 max), which affects athlete analytics accuracy but not core race planning features.")
                        .font(HYKATheme.body)
                        .foregroundColor(HYKATheme.Light.foreground)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(HYKATheme.spacingL)
                .background(
                    RoundedRectangle(cornerRadius: HYKATheme.cornerRadiusM)
                        .fill(Color.orange.opacity(0.15))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: HYKATheme.cornerRadiusM)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
                .padding(.horizontal, HYKATheme.spacingXXL)
                
                Spacer(minLength: HYKATheme.spacingXXL)
                
                // Buttons
                VStack(spacing: HYKATheme.spacingM) {
                    HYKAButton(
                        title: "Back",
                        style: .outline,
                        action: onBack
                    )
                    
                    HYKAButton(
                        title: "Continue",
                        style: .primary,
                        action: onNext
                    )
                    .disabled(!hasConnectedDevices)
                    .opacity(hasConnectedDevices ? 1.0 : 0.5)
                }
                .padding(.horizontal, HYKATheme.spacingXXL)
                .padding(.bottom, HYKATheme.spacingXXL)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .background(HYKATheme.backgroundColor)
            // Note: ErrorDisplay is applied at root level (MainApp), not here to avoid duplicate overlays
        }
        .onAppear {
            // Update OAuth manager with current session
            oauthManager.setSession(session)
            
            // Load existing connections from database
            Task {
                await loadExistingConnections()
            }
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
        .overlay {
            if isLoading {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    HYKALoadingCard(
                        message: oauthManager.connectingProvider != nil ? "Connecting to \(oauthManager.connectingProvider!)..." : "Connecting...",
                        backgroundColor: Color.hykaPurple
                    )
                }
            }
        }
    }
    
    private func handleDeviceConnection(_ deviceName: String) {
        // Disable connections for providers marked as coming soon
        if isComingSoon(deviceName) {
            return
        }
        
        // If already connected, prompt for disconnect
        if connectedDevices.contains(deviceName) {
            devicePendingDisconnect = deviceName
            showDisconnectAlert = true
            return
        }
        
        // Start OAuth flow
        Task {
            isLoading = true
            
            // Get root view controller for OAuth presentation
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootViewController = windowScene.windows.first?.rootViewController else {
                ErrorManager.shared.showError(title: "Connection Failed", message: "Could not find view controller for OAuth")
                isLoading = false
                return
            }
            
            do {
                try await oauthManager.connectProvider(deviceName, from: rootViewController)
                
                // Disconnect other devices if any (Enforce Single Connection)
                let otherDevices = connectedDevices.filter { $0 != deviceName }
                for otherDevice in otherDevices {
                    print("🔌 Disconnecting previous device: \(otherDevice)")
                    await disconnectDevice(otherDevice)
                }
                
                // Connection successful
                connectedDevices.insert(deviceName)
                print("✅ Successfully connected to \(deviceName)")
                
            } catch {
                print("❌ Error connecting to \(deviceName): \(error)")
                if case DeviceOAuthError.notImplemented(let message) = error {
                    ErrorManager.shared.showError(title: "Connection Not Available", message: "\(deviceName) connection not yet available. \(message)")
                } else {
                    ErrorManager.shared.showError(error, title: "Connection Failed")
                }
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
                ErrorManager.shared.showError(error, title: "Failed to Disconnect")
            }
        }
    }
    
    private func handleSignOut() async {
        isSigningOut = true
        await session.signOut()
        isSigningOut = false
    }
    
    // Helper function to get icon background color
    private func iconBackgroundColor(for deviceName: String, isConnected: Bool) -> Color {
        if isComingSoon(deviceName) {
            return HYKATheme.Light.muted.opacity(0.3)
        } else if isConnected {
            return Color.hykaPurple.opacity(0.2)
        } else {
            return HYKATheme.Light.muted.opacity(0.5) // Light gray for unselected
        }
    }
    
    private func isComingSoon(_ deviceName: String) -> Bool {
        deviceName == "Coros" // Only Coros is coming soon now
    }
    
    // Load existing connections from database
    private func loadExistingConnections() async {
        guard let userId = session.currentUser?.id ?? (session.isAuthenticated ? UUID(uuidString: UserDefaults.standard.string(forKey: "hyka.user.id") ?? "") : nil) else {
            return
        }
        
        do {
            let connections = try await SupabaseService.fetchOAuthConnections(userId: userId)
            let supportedNames = Set(devices.map { $0.name.lowercased() })
            
            var connectedSet: Set<String> = []
            for connection in connections {
                let providerKey = connection.provider.lowercased()
                if supportedNames.contains(providerKey) {
                    connectedSet.insert(providerKey.capitalized)
                }
            }
            
            await MainActor.run {
                connectedDevices = connectedSet
                print("✅ Loaded existing connections: \(connectedSet)")
            }
        } catch {
            // Non-critical error - just log, don't show to user
            print("⚠️ Error loading existing connections: \(error)")
        }
    }
}

struct GarminConnectionModal: View {
    @Binding var isPresented: Bool
    let onConnect: () -> Void
    
    @State private var email = ""
    @State private var password = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: HYKATheme.spacingXL) {
                    // URL Bar (simulated browser address bar)
                            HStack(spacing: HYKATheme.spacingM) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(HYKATheme.Light.mutedForeground)
                                
                                Text("https://connect.garmin.com")
                                    .font(.system(size: 12))
                            .foregroundColor(HYKATheme.Light.mutedForeground)
                        
                        Spacer()
                    }
                    .padding(HYKATheme.spacingM)
                    .background(HYKATheme.Light.muted)
                    .cornerRadius(HYKATheme.cornerRadiusS)
                    
                    // Login Form
                    VStack(spacing: HYKATheme.spacingL) {
                        VStack(alignment: .leading, spacing: HYKATheme.spacingS) {
                            HYKAUILabel(text: "Email", isRequired: true)
                            HYKAUIInput(
                                placeholder: "your.email@example.com",
                                text: $email,
                                keyboardType: .emailAddress,
                                textContentType: .emailAddress
                            )
                        }
                        
                        VStack(alignment: .leading, spacing: HYKATheme.spacingS) {
                            HYKAUILabel(text: "Password", isRequired: true)
                            HYKAUIInput(
                                placeholder: "Enter your password",
                                text: $password,
                                isSecure: true,
                                textContentType: .password
                            )
                        }
                    }
                    
                    Spacer(minLength: HYKATheme.spacingXXL)
                    
                    // Buttons
                    VStack(spacing: HYKATheme.spacingM) {
                        HYKAButton(
                            title: "Authorize HYKA",
                            style: .primary,
                            action: {
                                onConnect()
                                isPresented = false
                            }
                        )
                        
                        Button(action: {
                            isPresented = false
                        }) {
                            Text("Cancel")
                                .font(HYKATheme.button)
                                .foregroundColor(HYKATheme.Light.mutedForeground)
                        }
                    }
                }
                .padding(HYKATheme.spacingXXL)
            }
            .navigationTitle("Connect to Garmin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(HYKATheme.Light.foreground)
                    }
                }
            }
        }
    }
}

#Preview {
    ConnectDevicesView(onNext: {}, onSkip: {}, onBack: {})
}
