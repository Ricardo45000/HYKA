import Foundation
import UserNotifications
import UIKit
import Supabase
import Combine

/// Service to handle push notifications for activity completion
@MainActor
final class PushNotificationService: NSObject, ObservableObject {
    static let shared = PushNotificationService()
    
    @Published var isAuthorized = false
    @Published var deviceToken: String?
    
    private override init() {
        super.init()
    }
    
    /// Check current notification authorization status
    func checkAuthorizationStatus() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        
        await MainActor.run {
            self.isAuthorized = (settings.authorizationStatus == .authorized)
        }
        
        if settings.authorizationStatus == .authorized {
             await MainActor.run {
                 UIApplication.shared.registerForRemoteNotifications()
             }
        }
    }
    
    /// Request notification permissions and register for push notifications
    func requestAuthorization() async {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run {
                self.isAuthorized = granted
            }
            
            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                print("✅ Push notification authorization granted")
            } else {
                print("⚠️ Push notification authorization denied")
            }
        } catch {
            print("❌ Error requesting notification authorization: \(error)")
        }
    }
    
    /// Register device token with Supabase
    func registerDeviceToken(_ token: Data, userId: UUID) async {
        let tokenString = token.map { String(format: "%02.2hhx", $0) }.joined()
        
        await MainActor.run {
            self.deviceToken = tokenString
        }
        
        print("📱 Device token received: \(tokenString)")
        
        // Register with Supabase
        await saveDeviceTokenToSupabase(token: tokenString, userId: userId)
    }
    
    /// Save device token to Supabase user_devices table
    private func saveDeviceTokenToSupabase(token: String, userId: UUID) async {
        do {
            let timestampFormatter = ISO8601DateFormatter()
            timestampFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let updatedAt = timestampFormatter.string(from: Date())
            
            // Create a Codable struct for the data
            struct DeviceData: Codable {
                let userId: String
                let deviceToken: String
                let deviceType: String
                let pushEnabled: Bool
                let updatedAt: String
                
                enum CodingKeys: String, CodingKey {
                    case userId = "user_id"
                    case deviceToken = "device_token"
                    case deviceType = "device_type"
                    case pushEnabled = "push_enabled"
                    case updatedAt = "updated_at"
                }
            }
            
            let deviceData = DeviceData(
                userId: userId.uuidString,
                deviceToken: token,
                deviceType: "ios",
                pushEnabled: true,
                updatedAt: updatedAt
            )
            
            // Use upsert with onConflict parameter to resolve the duplicate key error
            let _ = try await Supa.client
                .from("user_devices")
                .upsert(deviceData, onConflict: "user_id,device_token")
                .execute()
            
            print("✅ Device token saved to Supabase")
        } catch {
            print("❌ Error saving device token: \(error)")
        }
    }
    
    /// Handle notification tap - deep link to activity
    func handleNotification(_ notification: UNNotification) {
        let userInfo = notification.request.content.userInfo
        
        if userInfo["activity_id"] as? String != nil,
           let deepLink = userInfo["deep_link"] as? String {
            print("🔗 Opening deep link: \(deepLink)")
            
            // Handle deep link to show activity
            if let url = URL(string: deepLink) {
                DispatchQueue.main.async {
                    UIApplication.shared.open(url)
                }
            }
        }
    }
    
    /// Reset the app badge count to zero
    func resetBadgeCount() {
        DispatchQueue.main.async {
            UNUserNotificationCenter.current().setBadgeCount(0) { error in
                if let error = error {
                    print("❌ Failed to reset badge count: \(error)")
                } else {
                    print("✅ Badge count reset to 0")
                }
            }
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension PushNotificationService: UNUserNotificationCenterDelegate {
    /// Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    /// Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        handleNotification(response.notification)
        completionHandler()
    }
}

