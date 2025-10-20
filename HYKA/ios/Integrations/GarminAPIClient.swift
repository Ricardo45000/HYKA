import Foundation

/// Helper to parse ISO8601 date strings
private func parseISO8601(_ string: String?) -> Date? {
    guard let string else { return nil }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.date(from: string) ?? ISO8601DateFormatter().date(from: string)
}

/// Client for Garmin OAuth 2.0 authentication only
/// 
/// Architecture (Official Garmin Developer Program approach):
/// - iOS app: OAuth 2.0 PKCE for user authorization ONLY
/// - Backend (Supabase Edge Functions): Receives webhooks from Garmin and pulls activity data
/// - iOS app: Reads activity data from Supabase (never calls Garmin APIs directly)
/// 
/// Data flow:
/// 1. User connects Garmin in iOS app → OAuth 2.0 authorization
/// 2. Edge Function stores access_token + garmin_user_id in Supabase
/// 3. Garmin pushes activity notifications → Edge Function webhook
/// 4. Edge Function fetches activity details using Pull Token (server-side)
/// 5. iOS app reads activities from Supabase
///
/// Note: This client no longer fetches activity/health data. All data fetching is server-side.
final class GarminAPIClient {
    // OAuth 2.0 access token (for user info only, not for activity data)
    private let accessToken: String
    
    init(accessToken: String) {
        self.accessToken = accessToken
    }
    
    /// Add OAuth 2.0 Bearer token authorization header to a request
    private func addBearerTokenHeader(to request: inout URLRequest) {
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
    }
    
    /// Fetch the Garmin user ID (required for OAuth connection)
    /// Reference: https://developerportal.garmin.com/sites/default/files/OAuth2PKCE_1.pdf (page 5)
    /// This is called once during initial connection to get the Garmin user ID
    func fetchUserId() async throws -> String {
        let url = URL(string: "https://apis.garmin.com/wellness-api/rest/user/id")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addBearerTokenHeader(to: &request)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GarminAPIError.invalidResponse
        }
        
        print("📡 User ID response: \(httpResponse.statusCode)")
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ User ID fetch failed: \(errorString)")
            throw GarminAPIError.apiError(message: errorString)
        }
        
        // Response format: {"userId": "d3315b1072421d0dd7c8f6b8e1de4df8"}
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let userId = json["userId"] as? String else {
            throw GarminAPIError.invalidResponse
        }
        
        print("✅ Garmin User ID: \(userId)")
        return userId
    }
    
    /// Fetch user permissions to see what data the user has granted access to
    /// Reference: https://developerportal.garmin.com/sites/default/files/OAuth2PKCE_1.pdf (page 6)
    /// This is the ONLY data fetching method in this client - everything else is server-side
    func fetchUserPermissions() async throws -> [String] {
        let url = URL(string: "https://apis.garmin.com/wellness-api/rest/user/permissions")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addBearerTokenHeader(to: &request)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GarminAPIError.invalidResponse
        }
        
        print("📡 User permissions response: \(httpResponse.statusCode)")
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ User permissions fetch failed: \(errorString)")
            throw GarminAPIError.apiError(message: errorString)
        }
        
        // Debug: Print raw response
        if let responseString = String(data: data, encoding: .utf8) {
            print("📋 Raw permissions response: \(responseString)")
        }
        
        // Try to parse permissions from response
        // Format may vary, so try multiple approaches
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            // Try parsing as {"permissions": ["READ_ACTIVITY", ...]}
            if let permissions = json["permissions"] as? [String] {
                print("✅ Garmin Permissions: \(permissions.joined(separator: ", "))")
                return permissions
            }
            
            print("⚠️ Could not parse permissions format - continuing without permissions check")
            return []
        }
        
        // If JSON parsing failed entirely, return empty array
        print("⚠️ Could not parse response as JSON - returning empty permissions")
        return []
    }
}

// MARK: - Garmin API Error

enum GarminAPIError: Error, LocalizedError {
    case notImplemented
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case apiError(message: String)
    case unauthorized
    
    var errorDescription: String? {
        switch self {
        case .notImplemented:
            return "Garmin API integration not yet implemented"
        case .invalidURL:
            return "Invalid URL for Garmin API request"
        case .invalidResponse:
            return "Invalid response from Garmin API"
        case .httpError(let statusCode):
            return "Garmin API HTTP error: \(statusCode)"
        case .apiError(let message):
            return "Garmin API error: \(message)"
        case .unauthorized:
            return "Unauthorized - check your credentials"
        }
    }
}

// MARK: - REMOVED: All activity/health/training data fetching methods
//
// The following methods have been removed as activity data is now fetched server-side:
// - fetchActivities(after:)
// - fetchActivity(activityId:)
// - fetchStreams(activityId:startTime:duration:)
// - fetchActivityFile(activityId:)
// - fetchLaps(activityId:)
// - fetchHealthMetrics(date:)
// - fetchHealthMetricsRange(startDate:endDate:)
// - fetchTrainingPlans(startDate:endDate:)
//
// All activity data is now fetched by Supabase Edge Functions via Garmin webhooks.
// iOS app reads activity data from Supabase tables, not directly from Garmin APIs.
//
// Architecture:
// 1. Garmin sends push/ping notifications → Edge Function webhook
// 2. Edge Function fetches activity details using Pull Token (server-side)
// 3. Edge Function stores activities in Supabase (garmin_activities, garmin_activity_samples tables)
// 4. iOS app reads from Supabase using RPC/REST API
//
// To fetch activities in your iOS app, query the garmin_activities table:
// let activities = try await Supa.client.from("garmin_activities").select("*").execute()
