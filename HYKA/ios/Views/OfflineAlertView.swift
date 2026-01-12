import SwiftUI

/// View modifier to show offline alert banner
struct OfflineAlertModifier: ViewModifier {
    @ObservedObject var networkMonitor = NetworkMonitor.shared
    @State private var showAlert = false
    @State private var showBanner = false
    @State private var showConnectedBanner = false
    @State private var bannerTimer: Timer?
    @State private var connectedBannerTimer: Timer?
    @State private var hasCheckedInitialState = false
    
    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                VStack {
                    // Offline banner (orange)
                    if showBanner && !networkMonitor.isConnected {
                        HStack {
                            Image(systemName: "wifi.slash")
                                .foregroundColor(.white)
                            Text("You're offline. Showing cached data.")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.orange)
                        .cornerRadius(8)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    // Connected banner (green)
                    if showConnectedBanner && networkMonitor.isConnected {
                        HStack {
                            Image(systemName: "wifi")
                                .foregroundColor(.white)
                            Text("Connected")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.green)
                        .cornerRadius(8)
                        .padding(.horizontal, 16)
                        .padding(.top, showBanner && !networkMonitor.isConnected ? 0 : 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    Spacer()
                }
                .animation(.easeInOut(duration: 0.3), value: showBanner)
                .animation(.easeInOut(duration: 0.3), value: showConnectedBanner)
            }
            .onAppear {
                // Check network status on app launch
                if !hasCheckedInitialState {
                    hasCheckedInitialState = true
                    if !networkMonitor.isConnected {
                        // Show offline banner immediately if offline on launch
                        showBanner = true
                        showAlert = true
                        
                        // Hide banner after 7 seconds
                        bannerTimer?.invalidate()
                        bannerTimer = Timer.scheduledTimer(withTimeInterval: 7.0, repeats: false) { _ in
                            withAnimation {
                                showBanner = false
                            }
                        }
                    }
                }
            }
            .onChange(of: networkMonitor.isConnected) { _, isConnected in
                if !isConnected {
                    // Show offline banner immediately
                    showBanner = true
                    showAlert = true
                    showConnectedBanner = false
                    connectedBannerTimer?.invalidate()
                    
                    // Hide banner after 7 seconds
                    bannerTimer?.invalidate()
                    bannerTimer = Timer.scheduledTimer(withTimeInterval: 7.0, repeats: false) { _ in
                        withAnimation {
                            showBanner = false
                        }
                    }
                } else {
                    // Hide offline banner immediately when back online
                    bannerTimer?.invalidate()
                    bannerTimer = nil
                    showBanner = false
                    
                    // Show connected banner briefly (only if we were previously offline)
                    if hasCheckedInitialState {
                        showConnectedBanner = true
                        connectedBannerTimer?.invalidate()
                        connectedBannerTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
                            withAnimation {
                                showConnectedBanner = false
                            }
                        }
                    }
                }
            }
            .alert("No Internet Connection", isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("You're currently offline. The app will show cached data. Some features may not be available.")
            }
            .onDisappear {
                bannerTimer?.invalidate()
                connectedBannerTimer?.invalidate()
            }
    }
}

extension View {
    /// Add offline alert banner to any view
    func withOfflineAlert() -> some View {
        modifier(OfflineAlertModifier())
    }
}

