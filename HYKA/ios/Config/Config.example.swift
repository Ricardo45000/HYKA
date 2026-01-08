import Foundation

/// Configuration file for HYKA app
/// 
/// ⚠️ IMPORTANT: 
/// 1. Copy this file to `Config.swift` (which is gitignored)
/// 2. Replace placeholder values with your actual keys
/// 3. Never commit `Config.swift` to Git
/// 4. IMPORTANT: Remove this file from your Xcode build target!
///    Right-click Config.example.swift → Target Membership → Uncheck your app target
///
/// To set up:
/// ```bash
/// cp ios/Config/Config.example.swift ios/Config/Config.swift
/// # Then edit Config.swift with your actual values
/// # Then in Xcode: Remove Config.example.swift from build target
/// ```

#if DEBUG && EXAMPLE_CONFIG
// Only compile this if EXAMPLE_CONFIG is defined (which it shouldn't be)
enum Config {
    // MARK: - Supabase Configuration
    
    /// Supabase project URL
    static let supabaseURL = "https://YOUR_PROJECT.supabase.co"
    
    /// Supabase anonymous key (public, safe for client-side)
    /// Get from: Supabase Dashboard → Settings → API → anon/public key
    static let supabaseAnonKey = "YOUR_SUPABASE_ANON_KEY_HERE"
    
    // MARK: - Garmin Configuration
    
    /// Garmin OAuth 2.0 Client ID
    /// Get from: Garmin Developer Portal → Your App → OAuth 2.0
    static let garminClientID = "YOUR_GARMIN_CLIENT_ID_HERE"
    
    /// Garmin OAuth 2.0 Redirect URI
    static let garminRedirectURI = "app.hyka.com://callback"
    
    // MARK: - Weather API Configuration
    
    /// Tomorrow.io API Key
    /// Get from: https://app.tomorrow.io/
    static let tomorrowIOAPIKey = "YOUR_TOMORROW_IO_API_KEY_HERE"
    
    // MARK: - Edge Function URLs
    
    /// Base URL for Supabase Edge Functions
    static var edgeFunctionsBaseURL: String {
        return "\(supabaseURL)/functions/v1"
    }
    
    /// Garmin OAuth callback Edge Function
    static var garminAuthCallbackURL: String {
        return "\(edgeFunctionsBaseURL)/garmin-auth-callback"
    }
    
    /// Garmin activity backfill Edge Function
    static var garminActivityBackfillURL: String {
        return "\(edgeFunctionsBaseURL)/garmin-activity-backfill"
    }
    
    /// Garmin activity direct fetch Edge Function (for immediate sync)
    static var garminActivityFetchURL: String {
        return "\(edgeFunctionsBaseURL)/garmin-activity-fetch"
    }
}
#else
// This file should not be compiled - it's just a template
// Make sure Config.swift exists and is in your build target instead
#endif

