import Foundation

/// Garmin API Configuration
/// 
/// Note: Pull Token has been REMOVED from iOS app
/// Pull Token is now stored and used ONLY in Supabase Edge Functions
/// iOS app only needs Client ID/Secret for OAuth 2.0 authentication
struct GarminConfig {
    // OAuth 2.0 Client ID
    private static let defaultConsumerKey = "695055f8-9786-4fda-a3a7-f7c2e88382f0"
    
    // OAuth 2.0 Client Secret
    // ⚠️ REMOVED: Client secret should NEVER be in client code
    // Client secret is now stored securely in Supabase Edge Functions
    // This file is deprecated - use Config.swift instead
    private static let defaultConsumerSecret = "" // REMOVED - use backend
    
    // Optional: Load from Info.plist
    private static var consumerKeyFromPlist: String? {
        guard let path = Bundle.main.path(forResource: "Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let key = plist["GARMIN_CONSUMER_KEY"] as? String else {
            return nil
        }
        return key
    }
    
    private static var consumerSecretFromPlist: String? {
        guard let path = Bundle.main.path(forResource: "Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let secret = plist["GARMIN_CONSUMER_SECRET"] as? String else {
            return nil
        }
        return secret
    }
    
    /// Get consumer key (prefer Info.plist, fallback to hardcoded)
    static var consumerKey: String {
        return consumerKeyFromPlist ?? defaultConsumerKey
    }
    
    /// Get consumer secret (prefer Info.plist, fallback to hardcoded)
    static var consumerSecret: String {
        return consumerSecretFromPlist ?? defaultConsumerSecret
    }
}

// MARK: - REMOVED: Pull Token
//
// Pull Token has been removed from iOS app and moved to backend (Supabase Edge Functions)
//
// Why:
// - Pull Tokens expire every 24 hours
// - Pull Tokens are used for server-side data fetching (not client-side)
// - Garmin's official architecture uses webhooks + server-side fetch
//
// Where Pull Token is now used:
// - Supabase Edge Functions (garmin-activity-fetch)
// - Stored in Supabase app_config table
// - Updated daily from Garmin Developer Portal
//
// iOS app no longer needs Pull Token because:
// - Activity data is fetched by Edge Functions (not iOS app)
// - iOS app only performs OAuth 2.0 authentication
// - iOS app reads activity data from Supabase (not from Garmin APIs)
