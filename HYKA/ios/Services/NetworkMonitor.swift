import Foundation
import Network
import Combine

/// Monitors network connectivity and provides offline/online status
@MainActor
final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    @Published var isConnected = true
    @Published var connectionType: ConnectionType = .unknown
    
    enum ConnectionType {
        case wifi
        case cellular
        case ethernet
        case unknown
        case none
    }
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    private init() {
        startMonitoring()
    }
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { path in
            Task { @MainActor in
                let wasConnected = NetworkMonitor.shared.isConnected
                NetworkMonitor.shared.isConnected = path.status == .satisfied
                
                // Determine connection type
                if path.status == .satisfied {
                    if path.usesInterfaceType(.wifi) {
                        NetworkMonitor.shared.connectionType = .wifi
                    } else if path.usesInterfaceType(.cellular) {
                        NetworkMonitor.shared.connectionType = .cellular
                    } else                     if path.usesInterfaceType(.wiredEthernet) {
                        NetworkMonitor.shared.connectionType = .ethernet
                    } else {
                        NetworkMonitor.shared.connectionType = .unknown
                    }
                } else {
                    NetworkMonitor.shared.connectionType = .none
                }
                
                // Log connection changes
                if wasConnected != NetworkMonitor.shared.isConnected {
                    print("🌐 Network status changed: \(NetworkMonitor.shared.isConnected ? "ONLINE" : "OFFLINE")")
                    if NetworkMonitor.shared.isConnected {
                        print("   Connection type: \(NetworkMonitor.shared.connectionType)")
                    }
                }
            }
        }
        
        monitor.start(queue: queue)
    }
    
    deinit {
        monitor.cancel()
    }
}

