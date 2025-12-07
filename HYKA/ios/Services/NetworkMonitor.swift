import Foundation
import Network
import Combine

/// Monitors network connectivity and provides offline/online status
@MainActor
final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    @Published var isConnected = true
    @Published var connectionType: ConnexionType = .unknown
    
    enum ConnexionType {
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
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self = self else { return }
                
                let wasConnected = self.isConnected
                self.isConnected = path.status == .satisfied
                
                // Determine connection type
                if path.status == .satisfied {
                    if path.usesInterfaceType(.wifi) {
                        self.connectionType = .wifi
                    } else if path.usesInterfaceType(.cellular) {
                        self.connectionType = .cellular
                    } else                     if path.usesInterfaceType(.wiredEthernet) {
                        self.connectionType = .ethernet
                    } else {
                        self.connectionType = .unknown
                    }
                } else {
                    self.connectionType = .none
                }
                
                // Log connection changes
                if wasConnected != self.isConnected {
                    print("🌐 Network status changed: \(self.isConnected ? "ONLINE" : "OFFLINE")")
                    if self.isConnected {
                        print("   Connexion type: \(self.connectionType)")
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

