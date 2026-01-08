import Foundation
import Supabase
import PostgREST
import Auth
import Combine

/// Service to handle all Supabase data operations
@MainActor
final class SupabaseService {
    
    // MARK: - User Profile
    
    /// Save user profile data to Supabase
    static func saveUserProfile(_ profile: UserProfile, userId: UUID) async throws {
        // Date formatter for DATE type (YYYY-MM-DD)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        
        // ISO8601 formatter for TIMESTAMP type
        let timestampFormatter = ISO8601DateFormatter()
        timestampFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        var runningDistances = profile.runningDistances.map { $0.rawValue }
        let trimmedCustomDistance = profile.customDistance.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedCustomDistance.isEmpty {
            runningDistances.append("Other:\(trimmedCustomDistance)")
        }
        
        let profileData = ProfileData(
            id: userId.uuidString,
            firstName: profile.firstName,
            lastName: profile.lastName,
            birthDate: dateFormatter.string(from: profile.birthDate),
            gender: profile.gender.rawValue,
            runningDistances: runningDistances,
            experienceLevel: profile.experienceLevel.rawValue,
            hasCompletedOnboarding: true,
            updatedAt: timestampFormatter.string(from: Date())
        )
        
        print("🔍 Saving profile with gender: \(profile.gender.rawValue)")
        print("🔍 Profile data: \(profileData)")
        
        do {
            try await Supa.client
                .from("profiles")
                .upsert(profileData)
                .execute()
            
            print("✅ User profile saved to Supabase")
        } catch {
            print("❌ Error saving user profile: \(error)")
            print("❌ Profile data: \(profileData)")
            throw error
        }
    }
    
    /// Fetch user profile from Supabase
    static func fetchUserProfile(userId: UUID) async throws -> UserProfile? {
        let response = try await Supa.client
            .from("profiles")
            .select()
            .eq("id", value: userId.uuidString)
            .single()
            .execute()
        
        // Parse response data - response.data is always Data
        var data: [String: Any]?
        
        if let parsed = try? JSONSerialization.jsonObject(with: response.data, options: []) as? [String: Any] {
            data = parsed
        }
        
        guard let data = data else {
            return nil
        }
        
        // Handle nullable fields - use empty strings if null
        let firstName = (data["first_name"] as? String) ?? ""
        let lastName = (data["last_name"] as? String) ?? ""
        
        // Parse birth date - handle nullable and different formats
        let birthDate: Date
        if let birthDateString = data["birth_date"] as? String {
            // Try ISO8601 first
            if let parsedDate = ISO8601DateFormatter().date(from: birthDateString) {
                birthDate = parsedDate
            } else {
                // Try simple YYYY-MM-DD formatter
                let simpleFormatter = DateFormatter()
                simpleFormatter.dateFormat = "yyyy-MM-dd"
                simpleFormatter.timeZone = TimeZone(secondsFromGMT: 0) // Important for DATE types
                if let parsedDate = simpleFormatter.date(from: birthDateString) {
                    birthDate = parsedDate
                } else {
                    print("⚠️ Could not parse birth date: \(birthDateString)")
                    birthDate = Date()
                }
            }
        } else {
            birthDate = Date() // Default to today if not set
        }
        
        // Parse gender - handle nullable
        let gender: UserProfile.Gender
        if let genderString = data["gender"] as? String,
           let parsedGender = UserProfile.Gender(rawValue: genderString) {
            gender = parsedGender
        } else {
            gender = .preferNotToSay // Default if not set
        }
        
        // Parse running distances - handle nullable
        var runningDistances: [UserProfile.RunningDistance] = []
        var customDistance = ""
        if let runningDistancesStrings = data["running_distances"] as? [String] {
            for value in runningDistancesStrings {
                if value.lowercased().hasPrefix("other:") {
                    customDistance = value.replacingOccurrences(of: "Other:", with: "", options: [.caseInsensitive])
                } else if let distance = UserProfile.RunningDistance(rawValue: value) {
                    runningDistances.append(distance)
                }
            }
        }
        
        // Parse experience level - handle nullable
        let experienceLevel: UserProfile.ExperienceLevel
        if let experienceLevelString = data["experience_level"] as? String,
           let parsedLevel = UserProfile.ExperienceLevel(rawValue: experienceLevelString) {
            experienceLevel = parsedLevel
        } else {
            experienceLevel = .beginner // Default if not set
        }
        
        return UserProfile(
            firstName: firstName,
            lastName: lastName,
            birthDate: birthDate,
            gender: gender,
            runningDistances: runningDistances,
            experienceLevel: experienceLevel,
            customDistance: customDistance
        )
    }
    
    /// Refresh access token using refresh token
    private static func refreshAccessToken(refreshToken: String) async throws -> (accessToken: String, expiresAt: Double) {
        let refreshURL = URL(string: "\(Config.supabaseURL)/auth/v1/token?grant_type=refresh_token")!
        var request = URLRequest(url: refreshURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        
        let body: [String: Any] = [
            "refresh_token": refreshToken
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accessToken = json["access_token"] as? String else {
            throw NSError(domain: "SupabaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to refresh token"])
        }
        
        // Extract expires_at
        let expiresAt = json["expires_at"] as? Double ?? Double(json["expires_at"] as? Int ?? 0)
        
        return (accessToken, expiresAt)
    }
    
    /// Check if user has completed onboarding
    static func hasCompletedOnboarding(userId: UUID, accessToken: String? = nil) async throws -> Bool {
        print("🔍 Checking onboarding status for user: \(userId.uuidString)")
        
        // Check if we have a session first
        var tokenToUse: String?
        do {
            let session = try await Supa.client.auth.session
            print("✅ Supabase SDK has session - user ID: \(session.user.id)")
            print("   Access token present: \(!session.accessToken.isEmpty)")
            tokenToUse = session.accessToken
        } catch {
            print("⚠️ Supabase SDK has NO session - RLS policies may fail!")
            print("   Error: \(error)")
            print("   This means auth.uid() will return NULL in RLS policies")
            
            // If access token is provided, use it directly
            if let providedToken = accessToken {
                print("   Using provided access token directly")
                tokenToUse = providedToken
            } else {
                // Try to get token from UserDefaults
                if let sessionData = UserDefaults.standard.data(forKey: "supabase.auth.session"),
                   let sessionDict = try? JSONSerialization.jsonObject(with: sessionData) as? [String: Any],
                   let token = sessionDict["access_token"] as? String,
                   let refreshToken = sessionDict["refresh_token"] as? String {
                    
                    // Check if token is expired
                    if let expiresAt = sessionDict["expires_at"] as? Double {
                        let expirationDate = Date(timeIntervalSince1970: expiresAt)
                        let now = Date()
                        if expirationDate > now.addingTimeInterval(60) { // Refresh if less than 1 min left
                            print("   Using access token from UserDefaults (not expired)")
                            tokenToUse = token
                        } else {
                            print("   Access token expired, refreshing...")
                            // Try to refresh the token
                            do {
                                let (newToken, newExpiresAt) = try await refreshAccessToken(refreshToken: refreshToken)
                                print("   ✅ Successfully refreshed access token")
                                tokenToUse = newToken
                                // Update UserDefaults with new token and expiration
                                var updatedSessionDict = sessionDict
                                updatedSessionDict["access_token"] = newToken
                                updatedSessionDict["expires_at"] = newExpiresAt
                                if let updatedData = try? JSONSerialization.data(withJSONObject: updatedSessionDict) {
                                    UserDefaults.standard.set(updatedData, forKey: "supabase.auth.session")
                                    print("   ✅ Updated session in UserDefaults with new token")
                                }
                            } catch {
                                print("   ⚠️ Failed to refresh token: \(error)")
                                print("   Using expired token anyway (will fail)")
                                tokenToUse = token
                            }
                        }
                    } else {
                        print("   Using access token from UserDefaults (no expiration info)")
                        tokenToUse = token
                    }
                }
            }
        }
        
        // If we have a token, use REST API directly with Authorization header
        if let token = tokenToUse {
            print("🔄 Querying profiles table using REST API with access token...")
            print("   User ID: \(userId.uuidString)")
            print("   Access token length: \(token.count)")
            
            do {
                // Use Supabase PostgREST API directly
                // PostgREST format: ?id=eq.{uuid}&select=has_completed_onboarding
                let userIdString = userId.uuidString.lowercased() // Ensure lowercase UUID
                var components = URLComponents(string: "\(Config.supabaseURL)/rest/v1/profiles")!
                components.queryItems = [
                    URLQueryItem(name: "id", value: "eq.\(userIdString)"),
                    URLQueryItem(name: "select", value: "has_completed_onboarding")
                ]
                
                guard let url = components.url else {
                    throw NSError(domain: "SupabaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
                }
                
                print("   Query URL: \(url.absoluteString)")
                
                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("return=representation", forHTTPHeaderField: "Prefer")
                
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NSError(domain: "SupabaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
                }
                
                print("   HTTP Status: \(httpResponse.statusCode)")
                
                if let responseString = String(data: data, encoding: .utf8) {
                    print("   Response body: \(responseString)")
                }
                
                if httpResponse.statusCode == 200 || httpResponse.statusCode == 206 {
                    // Parse response - PostgREST returns an array
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                        print("   Response is array with \(json.count) items")
                        if let first = json.first {
                            print("   First item keys: \(first.keys)")
                            if let hasCompleted = first["has_completed_onboarding"] as? Bool {
                                print("✅ Found onboarding status (REST API): \(hasCompleted)")
                                return hasCompleted
                            } else {
                                print("⚠️ No 'has_completed_onboarding' key in response")
                                print("   First item: \(first)")
                            }
                        } else {
                            print("⚠️ Empty array returned - no profile found")
                            return false
                        }
                    } else if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        // Sometimes PostgREST returns a single object
                        print("   Response is single object")
                        print("   Object keys: \(json.keys)")
                        if let hasCompleted = json["has_completed_onboarding"] as? Bool {
                            print("✅ Found onboarding status (REST API, single object): \(hasCompleted)")
                            return hasCompleted
                        } else {
                            print("⚠️ No 'has_completed_onboarding' key in response")
                            print("   Object: \(json)")
                        }
                    } else {
                        print("⚠️ Could not parse response as JSON")
                    }
                } else {
                    print("⚠️ HTTP error: \(httpResponse.statusCode)")
                    if let errorString = String(data: data, encoding: .utf8) {
                        print("   Error response: \(errorString)")
                    }
                }
                
                print("⚠️ REST API query failed or returned unexpected format")
            } catch {
                print("⚠️ REST API query error: \(error)")
                print("   Error details: \(error.localizedDescription)")
            }
        }
        
        // Fallback to SDK query (may fail if no session)
        do {
            // Use single() - if no rows exist, it will throw an error
            print("🔄 Querying profiles table using SDK (may fail if no session)...")
            let response = try await Supa.client
                .from("profiles")
                .select("has_completed_onboarding")
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
            
            print("✅ Query succeeded - got response from Supabase")
            
            // Parse response data - response.data is always Data
            var data: [String: Any]?
            
            if let parsed = try? JSONSerialization.jsonObject(with: response.data, options: []) as? [String: Any] {
                data = parsed
                // Debug: Log the actual JSON response
                print("🔍 Raw JSON response from Supabase: \(parsed)")
                print("🔍 All keys in response: \(parsed.keys)")
            }
            
            guard let data = data else {
                print("⚠️ Could not parse JSON response")
                return false
            }
            
            // Try both snake_case and camelCase (Supabase might convert)
            if let hasCompleted = data["has_completed_onboarding"] as? Bool {
                print("✅ Found onboarding status (snake_case): \(hasCompleted)")
                return hasCompleted
            }
            
            if let hasCompleted = data["hasCompletedOnboarding"] as? Bool {
                print("✅ Found onboarding status (camelCase): \(hasCompleted)")
                return hasCompleted
            }
            
            // If neither worked, log what we got
            print("⚠️ Could not find onboarding status in response")
            print("   Available keys: \(data.keys)")
            print("   Response data: \(data)")
            return false
            
        } catch {
            // If it's a "no rows" error, that's fine - user hasn't completed onboarding
            if let postgrestError = error as? PostgrestError {
                // PGRST116 = "JSON object requested, multiple (or no) rows returned"
                if postgrestError.code == "PGRST116" {
                    print("ℹ️ No profile found for user \(userId) - onboarding not completed yet")
                    return false
                }
                
                // Check if error message indicates no rows
                if postgrestError.message.contains("No rows returned") || 
                   postgrestError.message.contains("no rows") {
                    print("ℹ️ No profile found for user \(userId) - onboarding not completed yet")
                    return false
                }
            }
            
            // For other errors, log and rethrow
            print("❌ Error checking onboarding status: \(error)")
            if let postgrestError = error as? PostgrestError {
                print("   PostgrestError code: \(postgrestError.code ?? "nil")")
                print("   PostgrestError message: \(postgrestError.message)")
            }
            throw error
        }
    }
    
    /// Update onboarding completion status in Supabase
    static func updateOnboardingStatus(userId: UUID, completed: Bool) async throws {
        let timestampFormatter = ISO8601DateFormatter()
        timestampFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let updateData = OnboardingStatusUpdate(
            hasCompletedOnboarding: completed,
            updatedAt: timestampFormatter.string(from: Date())
        )
        
        try await Supa.client
            .from("profiles")
            .update(updateData)
            .eq("id", value: userId.uuidString)
            .execute()
        
        print("✅ Onboarding status updated in Supabase: \(completed)")
    }
    
    // MARK: - Race Plans
    
    /// Save GPX file data to race plan
    static func saveGPXFile(userId: UUID, racePlanId: UUID?, fileName: String, fileData: Data) async throws -> UUID {
        // Get or create race plan
        let finalRacePlanId: UUID
        
        if let existingRacePlanId = racePlanId {
            finalRacePlanId = existingRacePlanId
            print("📋 Using existing race plan ID: \(finalRacePlanId.uuidString)")
        } else {
            print("📋 Creating new race plan for GPX file")
            // Create a new race plan for this GPX file
            let racePlanData = RacePlanData(
                userId: userId.uuidString,
                title: fileName.replacingOccurrences(of: ".gpx", with: ""),
                createdAt: ISO8601DateFormatter().string(from: Date())
            )
            
            let response = try await Supa.client
                .from("race_plans")
                .insert(racePlanData)
                .select()
                .single()
                .execute()
            
            // Parse response to get the ID
            if let json = try? JSONSerialization.jsonObject(with: response.data, options: []) as? [String: Any],
               let idString = json["id"] as? String,
               let id = UUID(uuidString: idString) {
                finalRacePlanId = id
                print("✅ Created new race plan with ID: \(finalRacePlanId.uuidString)")
            } else {
                print("❌ Failed to parse race plan ID from response")
                if let jsonString = String(data: response.data, encoding: .utf8) {
                    print("❌ Response: \(jsonString)")
                }
                throw NSError(domain: "SupabaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse race plan ID from response"])
            }
        }
        
        print("📋 Final race plan ID to update: \(finalRacePlanId.uuidString)")
        
        // Upload GPX file to Supabase Storage instead of storing in database
        // This prevents statement timeout errors for large files
        let storagePath = "\(userId.uuidString)/\(finalRacePlanId.uuidString)/\(fileName)"
        
        print("📤 Uploading GPX file to storage: \(storagePath)")
        print("   File size: \(fileData.count) bytes (\(Double(fileData.count) / 1024 / 1024) MB)")
        
        do {
            // Upload to Supabase Storage bucket (create bucket if it doesn't exist)
            let fileOptions = FileOptions(
                contentType: "application/gpx+xml",
                upsert: true
            )
            
            try await Supa.client.storage
                .from("gpx-files")
                .upload(path: storagePath, file: fileData, options: fileOptions)
            
            print("✅ GPX file uploaded to storage")
            
            // Get public URL for the file
            let fileURL = try Supa.client.storage
                .from("gpx-files")
                .getPublicURL(path: storagePath)
            
            print("✅ GPX file URL: \(fileURL.absoluteString)")
            
            // Update race plan with GPX file metadata (not the file data)
            let updateData = RacePlanUpdateData(
                gpxFileName: fileName,
                gpxFileData: fileURL.absoluteString, // Store URL instead of base64 data
                updatedAt: ISO8601DateFormatter().string(from: Date())
            )
            
            print("📝 Updating race plan \(finalRacePlanId.uuidString) with GPX metadata:")
            print("   - File name: \(fileName)")
            print("   - File URL: \(fileURL.absoluteString)")
            
            let updateResponse = try await Supa.client
                .from("race_plans")
                .update(updateData)
                .eq("id", value: finalRacePlanId.uuidString)
                .select()
                .execute()
            
            // Verify the update was successful
            if let json = try? JSONSerialization.jsonObject(with: updateResponse.data, options: []) as? [String: Any] {
                print("✅ Update response: \(json)")
            } else if let jsonArray = try? JSONSerialization.jsonObject(with: updateResponse.data, options: []) as? [[String: Any]],
                      let first = jsonArray.first {
                print("✅ Update response (array): \(first)")
                if let updatedFileName = first["gpx_file_name"] as? String,
                   let updatedFileData = first["gpx_file_data"] as? String {
                    print("✅ Verified: gpx_file_name = '\(updatedFileName)', gpx_file_data = '\(updatedFileData.prefix(50))...'")
                } else {
                    print("⚠️ Warning: GPX fields not found in update response")
                }
            } else {
                print("⚠️ Warning: Could not parse update response")
            }
            
            print("✅ GPX file metadata saved to race plan")
            
        } catch {
            print("❌ Error uploading GPX file to storage: \(error)")
            
            // Check if it's a bucket not found error
            let errorString = String(describing: error)
            if errorString.contains("404") || errorString.contains("Bucket not found") {
                print("❌ Storage bucket 'gpx-files' not found!")
                print("   Please create the bucket by running the SQL script: create_gpx_storage_bucket.sql")
                throw NSError(
                    domain: "SupabaseService",
                    code: -1,
                    userInfo: [
                        NSLocalizedDescriptionKey: "Storage bucket not configured. Please create the 'gpx-files' bucket in Supabase Storage (see create_gpx_storage_bucket.sql)."
                    ]
                )
            }
            
            // For files larger than 5MB, don't try database fallback (will timeout)
            let fileSizeMB = Double(fileData.count) / 1024 / 1024
            if fileSizeMB > 5.0 {
                print("❌ File too large (\(String(format: "%.1f", fileSizeMB)) MB) for database storage")
                throw NSError(
                    domain: "SupabaseService",
                    code: -1,
                    userInfo: [
                        NSLocalizedDescriptionKey: "File is too large (\(String(format: "%.1f", fileSizeMB)) MB). Please ensure the 'gpx-files' storage bucket is created in Supabase."
                    ]
                )
            }
            
            // Fallback: Try storing in database only for small files (< 5MB)
            print("⚠️ Falling back to database storage (file size: \(String(format: "%.1f", fileSizeMB)) MB)...")
            let base64Data = fileData.base64EncodedString()
            let updateData = RacePlanUpdateData(
                gpxFileName: fileName,
                gpxFileData: base64Data,
                updatedAt: ISO8601DateFormatter().string(from: Date())
            )
            
            print("📝 Updating race plan \(finalRacePlanId.uuidString) with GPX data (fallback):")
            print("   - File name: \(fileName)")
            print("   - Data size: \(base64Data.count) characters (base64)")
            
            do {
                let updateResponse = try await Supa.client
                    .from("race_plans")
                    .update(updateData)
                    .eq("id", value: finalRacePlanId.uuidString)
                    .select()
                    .execute()
                
                // Verify the update was successful
                if let json = try? JSONSerialization.jsonObject(with: updateResponse.data, options: []) as? [String: Any] {
                    print("✅ Update response: \(json)")
                    if let updatedFileName = json["gpx_file_name"] as? String,
                       let updatedFileData = json["gpx_file_data"] as? String {
                        print("✅ Verified: gpx_file_name = '\(updatedFileName)', gpx_file_data length = \(updatedFileData.count)")
                    }
                } else if let jsonArray = try? JSONSerialization.jsonObject(with: updateResponse.data, options: []) as? [[String: Any]],
                          let first = jsonArray.first {
                    print("✅ Update response (array): \(first)")
                    if let updatedFileName = first["gpx_file_name"] as? String,
                       let updatedFileData = first["gpx_file_data"] as? String {
                        print("✅ Verified: gpx_file_name = '\(updatedFileName)', gpx_file_data length = \(updatedFileData.count)")
                    }
                }
                
                print("✅ GPX file saved to database (fallback)")
            } catch {
                print("❌ Database fallback also failed: \(error)")
                print("❌ Error details: \(error.localizedDescription)")
                throw NSError(
                    domain: "SupabaseService",
                    code: -1,
                    userInfo: [
                        NSLocalizedDescriptionKey: "Failed to save GPX file. Please ensure the 'gpx-files' storage bucket is created in Supabase Storage."
                    ]
                )
            }
        }
        
        try await generateRaceContent(for: finalRacePlanId, userId: userId, fileName: fileName, gpxData: fileData)
        
        print("✅ GPX file saved to race plan: \(finalRacePlanId)")
        return finalRacePlanId
    }
    
    static func updateRacePlanTitle(racePlanId: UUID, title: String) async throws {
        let timestampFormatter = ISO8601DateFormatter()
        timestampFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let updatePayload = RacePlanTitleUpdate(
            title: title,
            updatedAt: timestampFormatter.string(from: Date())
        )
        try await Supa.client
            .from("race_plans")
            .update(updatePayload)
            .eq("id", value: racePlanId.uuidString)
            .execute()
        print("✅ Race plan title updated for \(racePlanId.uuidString)")
    }
    
    static func updateRacePlanDate(racePlanId: UUID, raceDate: Date) async throws {
        let timestampFormatter = ISO8601DateFormatter()
        timestampFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let updatePayload = RacePlanDateUpdate(
            raceDate: timestampFormatter.string(from: raceDate),
            updatedAt: timestampFormatter.string(from: Date())
        )
        try await Supa.client
            .from("race_plans")
            .update(updatePayload)
            .eq("id", value: racePlanId.uuidString)
            .execute()
        print("✅ Race plan date updated for \(racePlanId.uuidString): \(timestampFormatter.string(from: raceDate))")
    }
    
    static func makeTrackPoints(from rawPoints: [GPXTrackPoint]) -> [TrackPoint] {
        var trackPoints: [TrackPoint] = []
        var cumulativeDistance: Double = 0
        // Process points in order to ensure deterministic results
        for raw in rawPoints {
            guard let lat = raw.lat, let lon = raw.lon else { continue }
            // Round coordinates to reasonable precision to avoid floating point inconsistencies
            let roundedLat = round(lat * 1_000_000.0) / 1_000_000.0 // 6 decimal places (~10cm precision)
            let roundedLon = round(lon * 1_000_000.0) / 1_000_000.0
            let elevation = raw.ele ?? trackPoints.last?.ele ?? 0
            if let previous = trackPoints.last {
                let segmentDistance = haversineDistance(lat1: previous.lat, lon1: previous.lon, lat2: roundedLat, lon2: roundedLon)
                // Round cumulative distance to avoid floating point accumulation errors
                cumulativeDistance = round((cumulativeDistance + segmentDistance) * 100.0) / 100.0 // Round to 2 decimal places (1cm precision)
            }
            trackPoints.append(TrackPoint(lat: roundedLat, lon: roundedLon, ele: elevation, distFromStart: cumulativeDistance, hr: raw.hr))
        }
        return trackPoints
    }
    
    private static func nearestTrackPointIndex(to distanceM: Double, in trackPoints: [TrackPoint]) -> Int {
        guard let last = trackPoints.last else { return 0 }
        if distanceM <= 0 { return 0 }
        if distanceM >= last.distFromStart { return trackPoints.count - 1 }
        var low = 0
        var high = trackPoints.count - 1
        while low <= high {
            let mid = (low + high) / 2
            if trackPoints[mid].distFromStart < distanceM {
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        let upperIndex = min(low, trackPoints.count - 1)
        let lowerIndex = max(upperIndex - 1, 0)
        let upperDiff = abs(trackPoints[upperIndex].distFromStart - distanceM)
        let lowerDiff = abs(trackPoints[lowerIndex].distFromStart - distanceM)
        return upperDiff < lowerDiff ? upperIndex : lowerIndex
    }
    
    private static func computeSegmentMetrics(trackPoints: [TrackPoint], startIndex: Int, endIndex: Int, paceSecondsPerKm: Double) -> AidStationSegmentMetrics {
        guard startIndex < endIndex, endIndex < trackPoints.count else {
            return AidStationSegmentMetrics(segmentDistanceM: 0, elevationGainM: 0, elevationLossM: 0, estimatedTimeSeconds: 0, averageHeartRate: nil, targetHeartRate: nil)
        }
        let startPoint = trackPoints[startIndex]
        let endPoint = trackPoints[endIndex]
        // Round segment distance to 2 decimal places (1cm precision) for consistency
        let segmentDistanceM = round(max(0, endPoint.distFromStart - startPoint.distFromStart) * 100.0) / 100.0
        var gain: Double = 0
        var loss: Double = 0
        var hrTotal: Double = 0
        var hrCount: Double = 0
        for idx in (startIndex + 1)...endIndex {
            // Round elevation values to ensure consistent calculations
            let previous = round(trackPoints[idx - 1].ele * 10.0) / 10.0
            let current = round(trackPoints[idx].ele * 10.0) / 10.0
            let delta = current - previous
            if delta > 0 {
                gain += delta
            } else {
                loss += abs(delta)
            }
            if let hr = trackPoints[idx].hr {
                hrTotal += Double(hr)
                hrCount += 1
            }
        }
        // Round elevation gain/loss to 1 decimal place for consistency
        gain = round(gain * 10.0) / 10.0
        loss = round(loss * 10.0) / 10.0
        let distanceKm = segmentDistanceM / 1000.0
        // Round estimated time to nearest second for consistency
        let estimatedTimeSeconds = round(distanceKm * paceSecondsPerKm)
        // Round average HR to nearest integer for consistency, then convert to Double
        let averageHR = hrCount > 0 ? Double(round(hrTotal / hrCount)) : nil
        return AidStationSegmentMetrics(segmentDistanceM: segmentDistanceM, elevationGainM: gain, elevationLossM: loss, estimatedTimeSeconds: estimatedTimeSeconds, averageHeartRate: averageHR, targetHeartRate: nil)
    }
    
    private static func buildAidStationsAndMetrics(from trackPoints: [TrackPoint], paceSecondsPerKm: Double) -> ([AidStation], [AidStationSegmentMetrics]) {
        guard let totalDistance = trackPoints.last?.distFromStart else {
            return ([], [])
        }
        let totalDistanceKm = totalDistance / 1000.0
        // Calculate checkpoint count deterministically with rounding
        let intermediateCheckpointCount = max(0, min(6, Int(round(totalDistanceKm / 25.0))))
        var checkpointIndices: [Int] = [0]
        if intermediateCheckpointCount > 0 {
            for i in 1...intermediateCheckpointCount {
                // Calculate target distance deterministically with explicit rounding
                let fraction = Double(i) / Double(intermediateCheckpointCount + 1)
                let targetDistance = round(totalDistance * fraction * 100.0) / 100.0 // Round to 2 decimal places for consistency
                let nearestIndex = nearestTrackPointIndex(to: targetDistance, in: trackPoints)
                if nearestIndex != checkpointIndices.last {
                    checkpointIndices.append(nearestIndex)
                }
            }
        }
        if let lastIndex = checkpointIndices.last, lastIndex != trackPoints.count - 1 {
            checkpointIndices.append(trackPoints.count - 1)
        } else if checkpointIndices.last != trackPoints.count - 1 {
            checkpointIndices.append(trackPoints.count - 1)
        }
        var aidStations: [AidStation] = []
        var segmentMetrics: [AidStationSegmentMetrics] = []
        for (idx, trackIndex) in checkpointIndices.enumerated() {
            let point = trackPoints[trackIndex]
            let distanceKm = point.distFromStart / 1000.0
            let name: String
            if idx == 0 {
                name = "Start"
            } else if idx == checkpointIndices.count - 1 {
                name = "Finish"
            } else {
                name = "Station \(idx)"
            }
            let services = AidService.ServiceType.allCases.map { AidService(type: $0, isAvailable: false) }
            aidStations.append(AidStation(name: name, distance: distanceKm, services: services))
            if idx == 0 {
                segmentMetrics.append(AidStationSegmentMetrics(segmentDistanceM: 0, elevationGainM: 0, elevationLossM: 0, estimatedTimeSeconds: 0, averageHeartRate: nil, targetHeartRate: nil))
            } else {
                let metric = computeSegmentMetrics(trackPoints: trackPoints, startIndex: checkpointIndices[idx - 1], endIndex: trackIndex, paceSecondsPerKm: paceSecondsPerKm)
                segmentMetrics.append(metric)
            }
        }
        return (aidStations, segmentMetrics)
    }
    
    private static func generateRaceContent(for racePlanId: UUID, userId: UUID, fileName: String, gpxData: Data) async throws {
        let parser = GPXParser()
        let rawPoints = parser.parse(data: gpxData)
        
        guard !rawPoints.isEmpty else {
            print("⚠️ GPX parser returned no points for \(fileName)")
            return
        }
        
        let trackPoints = makeTrackPoints(from: rawPoints)
        guard trackPoints.count > 1 else {
            print("⚠️ Not enough track points to compute race content")
            return
        }
        let defaultPaceSecondsPerKm = 300.0
        let (aidStations, segmentMetrics) = buildAidStationsAndMetrics(from: trackPoints, paceSecondsPerKm: defaultPaceSecondsPerKm)
        
        // Remove existing segments and fuel events
        try await Supa.client
            .from("race_plan_segments")
            .delete()
            .eq("race_plan_id", value: racePlanId.uuidString)
            .execute()
        
        try await Supa.client
            .from("fuel_events")
            .delete()
            .eq("race_plan_id", value: racePlanId.uuidString)
            .execute()
        
        try await updateAidStations(racePlanId: racePlanId, aidStations: aidStations, segmentMetrics: segmentMetrics, paceSecondsPerKm: defaultPaceSecondsPerKm)
        
        print("✅ Race plan content generated for \(fileName)")
    }
    
    private static func haversineDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let earthRadius = 6_371_000.0 // meters
        let dLat = (lat2 - lat1) * Double.pi / 180.0
        let dLon = (lon2 - lon1) * Double.pi / 180.0
        
        let a = sin(dLat / 2) * sin(dLat / 2) +
                cos(lat1 * Double.pi / 180.0) *
                cos(lat2 * Double.pi / 180.0) *
                sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        let distance = earthRadius * c
        // Round to 2 decimal places (1cm precision) for consistency
        return round(distance * 100.0) / 100.0
    }
    /// Save race plan with aid stations and preferences
    static func saveRacePlan(
        userId: UUID,
        raceDetails: RaceDetails,
        aidStations: [AidStation],
        preferences: StrategyPreferences
    ) async throws -> UUID {
        let timestampFormatter = ISO8601DateFormatter()
        timestampFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let racePlanData = RacePlanData(
            userId: userId.uuidString,
            title: raceDetails.name,
            createdAt: timestampFormatter.string(from: Date())
        )
        
        do {
            // 1. Insert race plan
            let racePlanResponse = try await Supa.client
                .from("race_plans")
                .insert(racePlanData)
                .select()
                .execute()
            
            print("🔍 Race plan response type: \(type(of: racePlanResponse.data))")
            
            // Try to parse the response - handle different formats
            var racePlanId: UUID?
            
            // Parse response data - response.data is always Data
            print("🔍 Response is Data, size: \(racePlanResponse.data.count) bytes")
            let parsedData = try? JSONSerialization.jsonObject(with: racePlanResponse.data, options: [])
            
            // Method 1: Dictionary response
            if let racePlanDict = parsedData as? [String: Any] {
                print("🔍 Response is dictionary: \(racePlanDict)")
                
                // Try UUID as string
                if let idString = racePlanDict["id"] as? String {
                    racePlanId = UUID(uuidString: idString)
                    print("🔍 Found ID as string: \(idString)")
                }
                // Try UUID directly
                else if let idUUID = racePlanDict["id"] as? UUID {
                    racePlanId = idUUID
                    print("🔍 Found ID as UUID: \(idUUID)")
                }
            }
            // Method 2: Array with single element
            else if let parsedArray = parsedData as? [Any],
                    let racePlanDict = parsedArray.first as? [String: Any] {
                print("🔍 Response is array with dictionary: \(racePlanDict)")
                
                if let idString = racePlanDict["id"] as? String {
                    racePlanId = UUID(uuidString: idString)
                } else if let idUUID = racePlanDict["id"] as? UUID {
                    racePlanId = idUUID
                }
            }
            
            guard let finalRacePlanId = racePlanId else {
                print("❌ Failed to parse race plan response")
                print("❌ Response data type: \(type(of: racePlanResponse.data))")
                if let jsonString = String(data: racePlanResponse.data, encoding: .utf8) {
                    print("❌ Response data as string: \(jsonString)")
                }
                throw NSError(domain: "SupabaseService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create race plan - could not parse ID from response"])
            }
            
            print("✅ Race plan saved to Supabase with ID: \(finalRacePlanId)")
            
            // Save race plan segments (aid stations)
            var previousDistanceKm: Double = 0
            for (index, station) in aidStations.enumerated() {
                let segmentDistanceM = max(0, (station.distance - previousDistanceKm) * 1000)
                let estimatedTimeSeconds = (segmentDistanceM / 1000.0) * Double(300)
                let segmentData = RacePlanSegmentData(
                    racePlanId: finalRacePlanId.uuidString,
                    index: index,
                    distanceM: station.distance * 1000, // Convert km to meters
                    targetPaceSPerKm: 600, // Default pace, will be calculated later
                    notes: station.name,
                    services: station.services.map { AidStationServicePayload(service: $0) },
                    segmentDistanceM: segmentDistanceM,
                    elevationGainM: 0,
                    elevationLossM: 0,
                    estimatedTimeSeconds: estimatedTimeSeconds,
                    averageHeartRate: nil
                )
                
                try await Supa.client
                    .from("race_plan_segments")
                    .insert(segmentData)
                    .execute()
                previousDistanceKm = station.distance
            }
            
            print("✅ \(aidStations.count) aid stations saved as race plan segments")
            
            // Save fuel events (placeholder - will be generated by strategy)
            // Fuel events are typically generated after strategy calculation
            // For now, we'll just save the race plan
            
            return finalRacePlanId
            
        } catch {
            print("❌ Error saving race plan: \(error)")
            throw error
        }
    }
    
    /// Fetch race plans for a user (with offline caching)
    static func fetchRacePlans(userId: UUID) async throws -> [RacePlanSummary] {
        // Check if offline - return cached data
        if !NetworkMonitor.shared.isConnected {
            print("📦 Offline: Loading race plans from cache")
            if let cached = DataCache.shared.loadArray(RacePlanSummary.self, key: .racePlans, userId: userId) {
                print("✅ Loaded \(cached.count) race plans from cache")
                return cached
            }
            throw NSError(domain: "SupabaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No internet connection and no cached data available"])
        }
        
        // Online - fetch from Supabase
        let response = try await Supa.client
            .from("race_plans")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("created_at", ascending: false)
            .execute()
        
        // Parse response data - response.data is always Data
        var dataArray: [[String: Any]]?
        
        if let parsed = try? JSONSerialization.jsonObject(with: response.data, options: []) as? [[String: Any]] {
            dataArray = parsed
        } else if let parsed = try? JSONSerialization.jsonObject(with: response.data, options: []) as? [String: Any] {
            // Handle single object response
            dataArray = [parsed]
        }
        
        guard let dataArray = dataArray else {
            // If fetch fails but we have cache, return cache
            if let cached = DataCache.shared.loadArray(RacePlanSummary.self, key: .racePlans, userId: userId) {
                print("⚠️ Fetch failed, returning cached data")
                return cached
            }
            return []
        }
        
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let plans = dataArray.compactMap { dict -> RacePlanSummary? in
            guard let idString = dict["id"] as? String,
                  let id = UUID(uuidString: idString),
                  let title = dict["title"] as? String,
                  let createdAtString = dict["created_at"] as? String,
                  let createdAt = isoFormatter.date(from: createdAtString) ?? ISO8601DateFormatter().date(from: createdAtString) else {
                return nil
            }
            
            var updatedAtDate: Date?
            if let updatedAtString = dict["updated_at"] as? String {
                updatedAtDate = isoFormatter.date(from: updatedAtString) ?? ISO8601DateFormatter().date(from: updatedAtString)
            }
            
            return RacePlanSummary(id: id, title: title, createdAt: createdAt, updatedAt: updatedAtDate ?? createdAt)
        }
        
        // Cache the fetched data
        DataCache.shared.saveArray(plans, key: .racePlans, userId: userId)
        print("✅ Fetched and cached \(plans.count) race plans")
        
        return plans
    }
    
    /// Fetch race plan segments for a race plan (with offline caching)
    static func fetchRacePlanSegments(racePlanId: UUID) async throws -> [RacePlanSegment] {
        // Get user_id from race plan to use for cache key
        // For now, we'll use racePlanId as additionalId
        let userId: UUID? = nil // We'll need to pass this or fetch it
        
        // Check if offline - return cached data
        if !NetworkMonitor.shared.isConnected {
            print("📦 Offline: Loading race plan segments from cache")
            if let cached = DataCache.shared.loadArray(RacePlanSegment.self, key: .racePlanSegments, userId: userId, additionalId: racePlanId) {
                print("✅ Loaded \(cached.count) race plan segments from cache")
                return cached
            }
            throw NSError(domain: "SupabaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No internet connection and no cached data available"])
        }
        
        let response = try await Supa.client
            .from("race_plan_segments")
            .select()
            .eq("race_plan_id", value: racePlanId.uuidString)
            .order("index", ascending: true)
            .execute()
        
        var dataArray: [[String: Any]]?
        
        if let parsed = try? JSONSerialization.jsonObject(with: response.data, options: []) as? [[String: Any]] {
            dataArray = parsed
        } else if let parsed = try? JSONSerialization.jsonObject(with: response.data, options: []) as? [String: Any] {
            dataArray = [parsed]
        }
        
        guard let dataArray = dataArray else {
            // If fetch fails but we have cache, return cache
            if let cached = DataCache.shared.loadArray(RacePlanSegment.self, key: .racePlanSegments, userId: userId, additionalId: racePlanId) {
                print("⚠️ Fetch failed, returning cached data")
                return cached
            }
            return []
        }
        
        let segments = dataArray.compactMap { dict -> RacePlanSegment? in
            guard let idString = dict["id"] as? String,
                  let id = UUID(uuidString: idString),
                  let distanceM = dict["distance_m"] as? Double,
                  let index = dict["index"] as? Int else {
                return nil
            }
            
            let notes = dict["notes"] as? String ?? ""
            let targetPace = dict["target_pace_s_per_km"] as? Int ?? 600
            let servicesPayload: [AidStationServicePayload]
            if let servicesAny = dict["services"],
               let servicesData = try? JSONSerialization.data(withJSONObject: servicesAny, options: []) {
                servicesPayload = (try? JSONDecoder().decode([AidStationServicePayload].self, from: servicesData)) ?? []
            } else {
                servicesPayload = []
            }
            let segmentDistanceM = dict["segment_distance_m"] as? Double ?? 0
            let elevationGainM = dict["elevation_gain_m"] as? Double ?? 0
            let elevationLossM = dict["elevation_loss_m"] as? Double ?? 0
            let estimatedTimeSeconds = dict["estimated_time_seconds"] as? Double ?? 0
            let averageHeartRate = dict["average_heart_rate"] as? Double
            
            return RacePlanSegment(
                id: id,
                racePlanId: racePlanId,
                index: index,
                distanceM: distanceM,
                targetPaceSPerKm: targetPace,
                notes: notes,
                services: servicesPayload,
                segmentDistanceM: segmentDistanceM,
                elevationGainM: elevationGainM,
                elevationLossM: elevationLossM,
                estimatedTimeSeconds: estimatedTimeSeconds,
                averageHeartRate: averageHeartRate
            )
        }
        
        // Cache the fetched segments
        DataCache.shared.saveArray(segments, key: .racePlanSegments, userId: userId, additionalId: racePlanId)
        print("✅ Fetched and cached \(segments.count) race plan segments")
        
        return segments
    }
    
    /// Fetch fuel events for a race plan
    static func fetchFuelEvents(racePlanId: UUID) async throws -> [SupabaseFuelEvent] {
        let response = try await Supa.client
            .from("fuel_events")
            .select()
            .eq("race_plan_id", value: racePlanId.uuidString)
            .order("at_minute", ascending: true)
            .execute()
        
        var dataArray: [[String: Any]]?
        
        if let parsed = try? JSONSerialization.jsonObject(with: response.data, options: []) as? [[String: Any]] {
            dataArray = parsed
        } else if let parsed = try? JSONSerialization.jsonObject(with: response.data, options: []) as? [String: Any] {
            dataArray = [parsed]
        }
        
        guard let dataArray = dataArray else {
            return []
        }
        
        return dataArray.compactMap { dict in
            guard let idString = dict["id"] as? String,
                  let id = UUID(uuidString: idString),
                  let atMinute = dict["at_minute"] as? Int,
                  let carbsG = dict["carbs_g"] as? Int else {
                return nil
            }
            
            let notes = dict["notes"] as? String
            
            return SupabaseFuelEvent(
                id: id,
                racePlanId: racePlanId,
                atMinute: atMinute,
                carbsG: carbsG,
                notes: notes
            )
        }
    }
    
    /// Update aid stations for a race plan
    static func updateAidStations(racePlanId: UUID, aidStations: [AidStation], segmentMetrics: [AidStationSegmentMetrics], paceSecondsPerKm: Double = 300) async throws {
        guard aidStations.count == segmentMetrics.count else {
            throw NSError(domain: "SupabaseService", code: -3, userInfo: [NSLocalizedDescriptionKey: "Aid stations and metrics count mismatch"])
        }
        // First, delete existing segments for this race plan
        try await Supa.client
            .from("race_plan_segments")
            .delete()
            .eq("race_plan_id", value: racePlanId.uuidString)
            .execute()
        
        print("✅ Deleted existing segments for race plan: \(racePlanId.uuidString)")
        
        // Then, insert new segments based on aid stations
        let targetPace = Int(paceSecondsPerKm)
        for (index, station) in aidStations.enumerated() {
            let metrics = segmentMetrics[index]
            let segmentData = RacePlanSegmentData(
                racePlanId: racePlanId.uuidString,
                index: index,
                distanceM: station.distance * 1000,
                targetPaceSPerKm: targetPace,
                notes: station.name,
                services: station.services.map { AidStationServicePayload(service: $0) },
                segmentDistanceM: metrics.segmentDistanceM,
                elevationGainM: metrics.elevationGainM,
                elevationLossM: metrics.elevationLossM,
                estimatedTimeSeconds: metrics.estimatedTimeSeconds,
                averageHeartRate: metrics.averageHeartRate
            )
            
            try await Supa.client
                .from("race_plan_segments")
                .insert(segmentData)
                .execute()
        }
        
        print("✅ Updated \(aidStations.count) aid stations for race plan: \(racePlanId.uuidString)")
    }
    
    // MARK: - Fuel Types
    
    /// Fetch fuel types for a user (defaults and custom entries stored in Supabase)
    static func fetchFuelTypes(userId: UUID) async throws -> [SupabaseFuelType] {
        // Check if offline - return cached data
        if !NetworkMonitor.shared.isConnected {
            print("📦 Offline: Loading fuel types from cache")
            if let cached = DataCache.shared.loadArray(SupabaseFuelType.self, key: .fuelTypes, userId: userId) {
                print("✅ Loaded \(cached.count) fuel types from cache")
                return cached
            }
            throw NSError(domain: "SupabaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No internet connection and no cached data available"])
        }
        
        let response = try await Supa.client
            .from("fuel_types")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("name", ascending: true)
            .execute()
        
        var dataArray: [[String: Any]]?
        
        if let parsed = try? JSONSerialization.jsonObject(with: response.data, options: []) as? [[String: Any]] {
            dataArray = parsed
        } else if let parsed = try? JSONSerialization.jsonObject(with: response.data, options: []) as? [String: Any] {
            dataArray = [parsed]
        }
        
        guard let dataArray = dataArray else {
            // If fetch fails but we have cache, return cache
            if let cached = DataCache.shared.loadArray(SupabaseFuelType.self, key: .fuelTypes, userId: userId) {
                print("⚠️ Fetch failed, returning cached fuel types")
                return cached
            }
            return []
        }
        
        let fuelTypes = dataArray.compactMap { dict -> SupabaseFuelType? in
            guard let idString = dict["id"] as? String,
                  let id = UUID(uuidString: idString),
                  let name = dict["name"] as? String,
                  let category = dict["category"] as? String,
                  let carbs = dict["carbs"] as? Int,
                  let sodium = dict["sodium"] as? Int else {
                return nil
            }
            
            let isCustom = (dict["is_custom"] as? Bool) ?? false
            
            return SupabaseFuelType(
                id: id,
                userId: userId,
                name: name,
                category: category,
                carbs: carbs,
                sodium: sodium,
                isCustom: isCustom
            )
        }
        
        // If fetch returned empty, check if we have cached data to return instead
        if fuelTypes.isEmpty {
            if let cached = DataCache.shared.loadArray(SupabaseFuelType.self, key: .fuelTypes, userId: userId), !cached.isEmpty {
                print("⚠️ Fetch returned empty, returning \(cached.count) cached fuel types")
                return cached
            }
            print("⚠️ Fetch returned empty and no cached fuel types available")
            return []
        }
        
        // Cache the fetched fuel types (only if we got data)
        DataCache.shared.saveArray(fuelTypes, key: .fuelTypes, userId: userId)
        print("✅ Fetched and cached \(fuelTypes.count) fuel types")
        
        return fuelTypes
    }
    
    static func ensureDefaultFuelTypes(userId: UUID) async throws {
        print("🔧 Ensuring default fuel types exist for user: \(userId)")
        let existingFuelTypes = try await fetchFuelTypes(userId: userId)
        print("📊 Found \(existingFuelTypes.count) existing fuel types")
        let existingNames = Set(existingFuelTypes.map { $0.name.lowercased() })
        print("📋 Existing fuel type names: \(existingNames)")
        
        var createdCount = 0
        for defaultFuel in defaultFuelCatalog {
            if !existingNames.contains(defaultFuel.name.lowercased()) {
                print("➕ Creating default fuel type: \(defaultFuel.name)")
                do {
                    _ = try await addFuelType(
                        userId: userId,
                        name: defaultFuel.name,
                        category: defaultFuel.category,
                        carbs: defaultFuel.carbs,
                        sodium: defaultFuel.sodium,
                        isCustom: false
                    )
                    createdCount += 1
                    print("✅ Successfully created: \(defaultFuel.name)")
                } catch {
                    print("❌ Failed to create fuel type \(defaultFuel.name): \(error)")
                    // Continue with other fuel types even if one fails
                }
            } else {
                print("ℹ️ Fuel type already exists: \(defaultFuel.name)")
            }
        }
        print("✅ Finished ensuring default fuel types. Created \(createdCount) new fuel types.")
    }
    
    static func addFuelType(userId: UUID, name: String, category: String, carbs: Int, sodium: Int, isCustom: Bool = true) async throws -> UUID {
        let fuelTypeData = FuelTypeData(
            userId: userId.uuidString,
            name: name,
            category: category,
            carbs: carbs,
            sodium: sodium,
            isCustom: isCustom
        )
        
        // Check if we have a session first
        var tokenToUse: String?
        var useSDK = false
        
        do {
            let session = try await Supa.client.auth.session
            print("✅ Supabase SDK has session - using SDK for insert")
            tokenToUse = session.accessToken
            useSDK = true
        } catch {
            print("⚠️ Supabase SDK has NO session - using REST API directly")
            print("   Error: \(error)")
            
            // Try to get token from UserDefaults
            if let sessionData = UserDefaults.standard.data(forKey: "supabase.auth.session"),
               let sessionDict = try? JSONSerialization.jsonObject(with: sessionData) as? [String: Any],
               let token = sessionDict["access_token"] as? String,
               let refreshToken = sessionDict["refresh_token"] as? String {
                
                // Check if token is expired
                if let expiresAt = sessionDict["expires_at"] as? Double {
                    let expirationDate = Date(timeIntervalSince1970: expiresAt)
                    let now = Date()
                    if expirationDate > now.addingTimeInterval(60) {
                        print("   Using access token from UserDefaults (not expired)")
                        tokenToUse = token
                    } else {
                        print("   Access token expired, refreshing...")
                        do {
                            let (newToken, newExpiresAt) = try await refreshAccessToken(refreshToken: refreshToken)
                            print("   ✅ Successfully refreshed access token")
                            tokenToUse = newToken
                            // Update UserDefaults with new token
                            var updatedSessionDict = sessionDict
                            updatedSessionDict["access_token"] = newToken
                            updatedSessionDict["expires_at"] = newExpiresAt
                            if let updatedData = try? JSONSerialization.data(withJSONObject: updatedSessionDict) {
                                UserDefaults.standard.set(updatedData, forKey: "supabase.auth.session")
                            }
                        } catch {
                            print("   ⚠️ Failed to refresh token: \(error)")
                            tokenToUse = token // Use expired token anyway
                        }
                    }
                } else {
                    tokenToUse = token
                }
            }
        }
        
        // Use SDK if we have a session, otherwise use REST API
        if useSDK {
            let response = try await Supa.client
                .from("fuel_types")
                .insert(fuelTypeData)
                .select()
                .execute()
            
            // Parse response to get created ID
            var data: [String: Any]?
            
            if let parsed = try? JSONSerialization.jsonObject(with: response.data, options: []) as? [[String: Any]],
               let first = parsed.first {
                data = first
            } else if let parsed = try? JSONSerialization.jsonObject(with: response.data, options: []) as? [String: Any] {
                data = parsed
            }
            
            guard let data = data,
                  let idString = data["id"] as? String,
                  let id = UUID(uuidString: idString) else {
                throw NSError(domain: "SupabaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create fuel type - could not parse ID"])
            }
            
            print("✅ Fuel type created: \(name) (\(isCustom ? "custom" : "default"))")
            return id
        } else if let token = tokenToUse {
            // Use REST API directly with access token
            print("🔄 Creating fuel type using REST API with access token...")
            
            let url = URL(string: "\(Config.supabaseURL)/rest/v1/fuel_types")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("return=representation", forHTTPHeaderField: "Prefer")
            
            // Encode fuelTypeData to JSON
            // Note: FuelTypeData already has custom CodingKeys, so don't use .convertToSnakeCase
            let encoder = JSONEncoder()
            let jsonData = try encoder.encode(fuelTypeData)
            request.httpBody = jsonData
            
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(domain: "SupabaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
            }
            
            print("   HTTP Status: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 201 || httpResponse.statusCode == 200 {
                // Parse response - PostgREST returns an array
                if let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                   let first = json.first,
                   let idString = first["id"] as? String,
                   let id = UUID(uuidString: idString) {
                    print("✅ Fuel type created via REST API: \(name) (\(isCustom ? "custom" : "default"))")
                    return id
                } else if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let idString = json["id"] as? String,
                          let id = UUID(uuidString: idString) {
                    print("✅ Fuel type created via REST API: \(name) (\(isCustom ? "custom" : "default"))")
                    return id
                } else {
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("⚠️ Response body: \(responseString)")
                    }
                    throw NSError(domain: "SupabaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create fuel type - could not parse ID from REST API response"])
                }
            } else {
                if let responseString = String(data: data, encoding: .utf8) {
                    print("⚠️ Error response: \(responseString)")
                }
                throw NSError(domain: "SupabaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create fuel type - HTTP \(httpResponse.statusCode)"])
            }
        } else {
            throw NSError(domain: "SupabaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No access token available for fuel type creation"])
        }
    }
    
    static func updateFuelType(fuelTypeId: UUID, name: String, category: String, carbs: Int, sodium: Int) async throws {
        let updateData = FuelTypeUpdateData(
            name: name,
            category: category,
            carbs: carbs,
            sodium: sodium
        )
        
        try await Supa.client
            .from("fuel_types")
            .update(updateData)
            .eq("id", value: fuelTypeId.uuidString)
            .execute()
        
        print("✅ Fuel type updated: \(name)")
    }
    
    /// Delete a fuel type
    static func deleteFuelType(fuelTypeId: UUID) async throws {
        try await Supa.client
            .from("fuel_types")
            .delete()
            .eq("id", value: fuelTypeId.uuidString)
            .execute()
        
        print("✅ Fuel type deleted")
    }
    
    // MARK: - Device Connections
    
    /// Save OAuth connection
    static func saveOAuthConnection(userId: UUID, provider: String, accessToken: String, refreshToken: String? = nil, tokenSecret: String? = nil, expiresAt: Date? = nil) async throws {
        let timestampFormatter = ISO8601DateFormatter()
        timestampFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        // Note: tokenSecret parameter is kept for API compatibility but not stored
        // The database table doesn't have a token_secret column
        struct OAuthConnectionInsert: Codable {
            let userId: String
            let provider: String
            let accessToken: String
            let refreshToken: String?
            let expiresAt: String?
            let createdAt: String
            let updatedAt: String
            
            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
                case provider
                case accessToken = "access_token"
                case refreshToken = "refresh_token"
                case expiresAt = "expires_at"
                case createdAt = "created_at"
                case updatedAt = "updated_at"
            }
        }
        
        let connectionData = OAuthConnectionInsert(
            userId: userId.uuidString,
            provider: provider.lowercased(),
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: expiresAt != nil ? timestampFormatter.string(from: expiresAt!) : nil,
            createdAt: timestampFormatter.string(from: Date()),
            updatedAt: timestampFormatter.string(from: Date())
        )
        
        try await Supa.client
            .from("oauth_connections")
            .upsert(connectionData)
            .execute()
        
        print("✅ OAuth connection saved for provider: \(provider)")
    }
    
    /// Fetch OAuth connections for a user
    static func fetchOAuthConnections(userId: UUID) async throws -> [OAuthConnection] {
        let response = try await Supa.client
            .from("oauth_connections")
            .select()
            .eq("user_id", value: userId.uuidString)
            .execute()
        
        // Parse response data - response.data is always Data
        var dataArray: [[String: Any]]?
        
        if let parsed = try? JSONSerialization.jsonObject(with: response.data, options: []) as? [[String: Any]] {
            dataArray = parsed
        } else if let parsed = try? JSONSerialization.jsonObject(with: response.data, options: []) as? [String: Any] {
            // Handle single object response
            dataArray = [parsed]
        }
        
        guard let dataArray = dataArray else {
            return []
        }
        
        let timestampFormatter = ISO8601DateFormatter()
        timestampFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        return dataArray.compactMap { dict in
            guard let provider = dict["provider"] as? String,
                  let accessToken = dict["access_token"] as? String else {
                return nil
            }
            
            let refreshToken = dict["refresh_token"] as? String
            let expiresAtString = dict["expires_at"] as? String
            let expiresAt = expiresAtString != nil ? timestampFormatter.date(from: expiresAtString!) : nil
            
            return OAuthConnection(
                provider: provider,
                accessToken: accessToken,
                refreshToken: refreshToken,
                expiresAt: expiresAt
            )
        }
    }

    /// Delete an OAuth connection for a provider
    static func deleteOAuthConnection(userId: UUID, provider: String) async throws {
        try await Supa.client
            .from("oauth_connections")
            .delete()
            .eq("user_id", value: userId.uuidString)
            .eq("provider", value: provider.lowercased())
            .execute()
        
        print("🗑️ Deleted OAuth connection for provider: \(provider)")
    }
    
    /// Get OAuth access token for a provider
    static func getOAuthAccessToken(userId: UUID, provider: String) async throws -> String? {
        let connections = try await fetchOAuthConnections(userId: userId)
        return connections.first(where: { $0.provider.lowercased() == provider.lowercased() })?.accessToken
    }
    
    static func getOAuthRefreshToken(userId: UUID, provider: String) async throws -> String? {
        let connections = try await fetchOAuthConnections(userId: userId)
        return connections.first(where: { $0.provider.lowercased() == provider.lowercased() })?.refreshToken
    }
    
    // MARK: - Workouts
    
    /// Save workout to Supabase
    static func saveWorkout(userId: UUID, workout: ProviderWorkout, provider: String) async throws -> UUID {
        let timestampFormatter = ISO8601DateFormatter()
        timestampFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        // Create Codable struct for workout
        let workoutData = WorkoutData(
            userId: userId.uuidString,
            provider: provider.lowercased(),
            providerActivityId: workout.providerActivityId,
            name: workout.name,
            startTime: timestampFormatter.string(from: workout.startTime),
            elapsedSeconds: workout.elapsedSeconds,
            movingSeconds: workout.movingSeconds,
            distanceM: workout.distanceMeters,
            elevationGainM: workout.elevationGainMeters,
            avgHR: workout.avgHR,
            maxHR: workout.maxHR,
            avgPaceSPerKm: workout.avgPaceSPerKm,
            activityTypeCode: workout.activityTypeCode.rawValue,
            startTimezoneOffsetMinutes: workout.timezoneOffsetMinutes
        )
        
        let response = try await Supa.client
            .from("workouts")
            .insert(workoutData)
            .select()
            .execute()
        
        // Parse response to get workout ID - response.data is always Data
        var data: [String: Any]?
        
        if let parsed = try? JSONSerialization.jsonObject(with: response.data, options: []) {
            // Handle array response (Supabase returns array for insert)
            if let array = parsed as? [[String: Any]], let first = array.first {
                data = first
            } else if let dict = parsed as? [String: Any] {
                data = dict
            }
        }
        
        guard let data = data,
              let idString = data["id"] as? String,
              let id = UUID(uuidString: idString) else {
            throw NSError(domain: "SupabaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse workout ID"])
        }
        
        return id
    }
    
    /// Fetch workout by provider activity ID
    static func fetchWorkoutByProviderId(userId: UUID, provider: String, providerActivityId: String) async throws -> Workout? {
        let response = try await Supa.client
            .from("workouts")
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("provider", value: provider.lowercased())
            .eq("provider_activity_id", value: providerActivityId)
            .execute()
        
        // Parse response data - response.data is always Data
        var dataArray: [[String: Any]]?
        
        if let parsed = try? JSONSerialization.jsonObject(with: response.data, options: []) as? [[String: Any]] {
            dataArray = parsed
        } else if let parsed = try? JSONSerialization.jsonObject(with: response.data, options: []) as? [String: Any] {
            // Handle single object response
            dataArray = [parsed]
        }
        
        guard let dataArray = dataArray,
              let first = dataArray.first,
              let idString = first["id"] as? String,
              let id = UUID(uuidString: idString) else {
            return nil
        }
        
        return Workout(
            id: id,
            name: first["name"] as? String,
            distance_m: first["distance_m"] as? Double,
            elapsed_seconds: first["elapsed_seconds"] as? Int,
            activity_type_code: (first["activity_type_code"] as? String).flatMap { ActivityTypeCode(rawValue: $0) },
            start_timezone_offset_minutes: first["start_timezone_offset_minutes"] as? Int
        )
    }
    
    // MARK: - Samples
    
    /// Save samples to Supabase
    static func saveSamples(workoutId: UUID, samples: [ProviderSample]) async throws {
        guard !samples.isEmpty else { return }
        
        // Convert samples to Codable structs
        let samplesData = samples.map { sample in
            SampleData(
                workoutId: workoutId.uuidString,
                tS: sample.tS,
                lat: sample.lat,
                lon: sample.lon,
                altM: sample.altM,
                hr: sample.hr,
                cadence: sample.cadence,
                paceSPerKm: sample.paceSPerKm,
                airTemperatureC: sample.airTemperatureC,
                speedMPerS: sample.speedMPerS,
                stepsPerMinute: sample.stepsPerMinute
            )
        }
        
        // Insert in batches (Supabase has limits)
        let batchSize = 1000
        for i in stride(from: 0, to: samplesData.count, by: batchSize) {
            let end = min(i + batchSize, samplesData.count)
            let batch = Array(samplesData[i..<end])
            
            try await Supa.client
                .from("samples")
                .insert(batch)
                .execute()
        }
        
        print("✅ Saved \(samples.count) samples for workout \(workoutId)")
    }
    
    // MARK: - Laps
    
    /// Save laps to Supabase
    static func saveLaps(workoutId: UUID, laps: [ProviderLap]) async throws {
        guard !laps.isEmpty else { return }
        
        // Convert laps to Codable structs
        let lapsData = laps.map { lap in
            LapData(
                workoutId: workoutId.uuidString,
                index: lap.index,
                startOffsetS: lap.startOffsetS,
                durationS: lap.durationS,
                distanceM: lap.distanceM,
                elevationGainM: lap.elevationGainM ?? 0,
                avgHR: lap.avgHR,
                avgPaceSPerKm: lap.avgPaceSPerKm
            )
        }
        
        try await Supa.client
            .from("laps")
            .insert(lapsData)
            .execute()
        
        print("✅ Saved \(laps.count) laps for workout \(workoutId)")
    }
    
    /// Get the most recent workout timestamp for a provider (for incremental sync)
    static func getLastWorkoutTimestamp(userId: UUID, provider: String) async throws -> Date? {
        let response = try await Supa.client
            .from("workouts")
            .select("start_time")
            .eq("user_id", value: userId.uuidString)
            .eq("provider", value: provider.lowercased())
            .order("start_time", ascending: false)
            .limit(1)
            .execute()
        
        guard let json = try? JSONSerialization.jsonObject(with: response.data) else { return nil }
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let array = json as? [[String: Any]], let first = array.first,
           let startString = first["start_date"] as? String ?? first["start_time"] as? String,
           let startTime = formatter.date(from: startString) ?? ISO8601DateFormatter().date(from: startString) {
            return startTime
        }
        
        return nil
    }
    
    static func fetchWorkouts(userId: UUID) async throws -> [WorkoutSummary] {
        print("📊 fetchWorkouts: Fetching activities for user \(userId.uuidString)")
        
        // Check if offline - return cached data
        if !NetworkMonitor.shared.isConnected {
            print("📦 Offline: Loading workouts from cache")
            if let cached = DataCache.shared.loadArray(WorkoutSummary.self, key: .workouts, userId: userId) {
                print("✅ Loaded \(cached.count) workouts from cache")
                return cached
            }
            throw NSError(domain: "SupabaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No internet connection and no cached data available"])
        }
        
        // Use unified_activities view to get activities from all providers (including Garmin)
        do {
            let response = try await Supa.client
                .from("unified_activities")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("start_date", ascending: false) // unified_activities uses start_date
                .limit(100) // Limit to most recent 100 activities
                .execute()
            
            print("📊 fetchWorkouts: Response received, data size: \(response.data.count) bytes")
            
            guard let json = try? JSONSerialization.jsonObject(with: response.data) else {
                print("⚠️ fetchWorkouts: Failed to parse JSON response")
                return []
            }
            
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            let array: [[String: Any]]
            if let list = json as? [[String: Any]] {
                array = list
                print("📊 fetchWorkouts: Found \(list.count) activities in response")
            } else if let single = json as? [String: Any] {
                array = [single]
                print("📊 fetchWorkouts: Found 1 activity in response")
            } else {
                array = []
                print("⚠️ fetchWorkouts: No activities found in response")
            }
            
            let workouts = array.compactMap { dict -> WorkoutSummary? in
                guard let idString = dict["id"] as? String, let id = UUID(uuidString: idString) else {
                    print("⚠️ fetchWorkouts: Invalid activity ID: \(dict["id"] ?? "nil")")
                    return nil
                }
                // unified_activities uses different field names - handle all variations
                let distance = dict["distance_meters"] as? Double ?? dict["distance_m"] as? Double
                // Handle elapsed_time (from unified_activities) vs duration_seconds/elapsed_seconds
                let elapsed = dict["elapsed_time"] as? Int ?? dict["duration_seconds"] as? Int ?? dict["elapsed_seconds"] as? Int
                let avgHR = dict["average_heart_rate"] as? Int ?? dict["avg_hr"] as? Int
                let maxHR = dict["max_heart_rate"] as? Int ?? dict["max_hr"] as? Int
                let calories = dict["calories"] as? Int ?? dict["calories_consumed"] as? Int
                let startTime: Date?
                // Handle start_date (from unified_activities) vs start_time
                if let startString = dict["start_date"] as? String ?? dict["start_time"] as? String {
                    startTime = formatter.date(from: startString) ?? ISO8601DateFormatter().date(from: startString)
                } else {
                    startTime = nil
                }
                
                let provider = dict["provider"] as? String ?? "unknown"
                // Handle activity_name (from unified_activities) vs name
                let name = dict["activity_name"] as? String ?? dict["name"] as? String ?? "Unknown Activity"
                print("   ✓ Activity: \(name) (\(provider)) - \(distance ?? 0)m, \(elapsed ?? 0)s, HR: \(avgHR ?? 0)/\(maxHR ?? 0) bpm")
                
                return WorkoutSummary(
                    id: id,
                    distanceM: distance,
                    elapsedSeconds: elapsed,
                    avgHR: avgHR,
                    maxHR: maxHR,
                    calories: calories,
                    startTime: startTime
                )
            }
            
            print("✅ fetchWorkouts: Successfully parsed \(workouts.count) workouts")
            return workouts
            
        } catch {
            print("❌ fetchWorkouts: Error fetching activities: \(error.localizedDescription)")
            print("   Error details: \(error)")
            // If unified_activities view doesn't exist, try falling back to workouts table
            print("   Attempting fallback to workouts table...")
            
            let response = try await Supa.client
                .from("workouts")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("start_time", ascending: false)
                .limit(100)
                .execute()
            
            guard let json = try? JSONSerialization.jsonObject(with: response.data),
                  let list = json as? [[String: Any]] else {
                print("⚠️ fetchWorkouts: Fallback also failed")
                // If fetch fails but we have cache, return cache
                if let cached = DataCache.shared.loadArray(WorkoutSummary.self, key: .workouts, userId: userId) {
                    print("⚠️ Returning cached data after fallback failure")
                    return cached
                }
                return []
            }
            
            print("📊 fetchWorkouts: Fallback found \(list.count) activities in workouts table")
            // Parse workouts table format (different field names)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            let fallbackWorkouts = list.compactMap { dict -> WorkoutSummary? in
                guard let idString = dict["id"] as? String, let id = UUID(uuidString: idString) else { return nil }
                let distance = dict["distance_m"] as? Double
                let elapsed = dict["elapsed_seconds"] as? Int
                let avgHR = dict["avg_hr"] as? Int
                let maxHR = dict["max_hr"] as? Int
                let calories = dict["calories"] as? Int
                let startTime: Date?
                if let startString = dict["start_time"] as? String {
                    startTime = formatter.date(from: startString) ?? ISO8601DateFormatter().date(from: startString)
                } else {
                    startTime = nil
                }
                return WorkoutSummary(
                    id: id,
                    distanceM: distance,
                    elapsedSeconds: elapsed,
                    avgHR: avgHR,
                    maxHR: maxHR,
                    calories: calories,
                    startTime: startTime
                )
            }
            
            // Cache the fallback workouts too
            DataCache.shared.saveArray(fallbackWorkouts, key: .workouts, userId: userId)
            print("✅ Cached \(fallbackWorkouts.count) fallback workouts")
            
            return fallbackWorkouts
        }
    }
    
    static func fetchSamples(workoutId: UUID) async throws -> [WorkoutSample] {
        // Use RPC function to get samples from both garmin_activity_samples and samples tables
        let response = try await Supa.client
            .rpc("get_activity_samples", params: ["p_activity_id": workoutId.uuidString])
            .execute()
        
        guard let json = try? JSONSerialization.jsonObject(with: response.data) else { return [] }
        let array: [[String: Any]]
        if let list = json as? [[String: Any]] {
            array = list
        } else if let single = json as? [String: Any] {
            array = [single]
        } else {
            array = []
        }
        
        return array.compactMap { dict in
            // RPC function returns timestamp_seconds (BIGINT), not t_s
            guard let t = dict["timestamp_seconds"] as? Int64 ?? (dict["timestamp_seconds"] as? Int).map(Int64.init) else { return nil }
            
            // Map RPC function fields to WorkoutSample
            let hr = dict["heart_rate"] as? Int ?? dict["hr"] as? Int
            let climb = dict["elevation_meters"] as? Double ?? dict["alt_m"] as? Double
            let cadence = dict["steps_per_minute"] as? Int ?? dict["cadence"] as? Int
            let speedMps = dict["speed_mps"] as? Double ?? dict["speed_m_per_s"] as? Double
            
            // Calculate pace from speed if available (pace = 1000 / speed_mps)
            let pace: Int?
            if let speed = speedMps, speed > 0 {
                pace = Int(1000.0 / speed)
            } else {
                pace = dict["pace_s_per_km"] as? Int
            }
            
            return WorkoutSample(
                timeOffsetSeconds: Int(t),
                paceSecondsPerKm: pace,
                heartRate: hr,
                altitudeMeters: climb,
                cadence: cadence
            )
        }
    }
    
    // MARK: - Health Metrics
    
    /// Save health metrics to Supabase
    static func saveHealthMetrics(userId: UUID, provider: String, metrics: HealthMetrics) async throws {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]
        
        var inferredAge = metrics.ageYears
        if inferredAge == nil {
            do {
                if let profile = try await fetchUserProfile(userId: userId) {
                    inferredAge = calculateAgeYears(from: profile.birthDate)
                }
            } catch {
                // Ignore age inference errors; proceed without age.
            }
        }
        let inferredFitnessAge = metrics.fitnessAge ?? computeFitnessAge(vo2Max: metrics.vo2Max, chronologicalAge: inferredAge)
        
        let metricsData = HealthMetricsData(
            userId: userId.uuidString,
            provider: provider.lowercased(),
            date: dateFormatter.string(from: metrics.date),
            vo2Max: metrics.vo2Max,
            sleepScore: metrics.sleepScore,
            recoveryScore: metrics.recoveryScore,
            restingHeartRate: metrics.restingHeartRate,
            weightKg: metrics.weightKg,
            caloriesConsumed: metrics.caloriesConsumed,
            ageYears: inferredAge,
            fitnessAge: inferredFitnessAge
        )
        
        try await Supa.client
            .from("health_metrics")
            .upsert(metricsData)
            .execute()
        
        print("✅ Health metrics saved for provider: \(provider), date: \(metrics.date)")
    }
    
    private static func calculateAgeYears(from birthDate: Date, referenceDate: Date = Date()) -> Int {
        let components = Calendar.current.dateComponents([.year], from: birthDate, to: referenceDate)
        return components.year ?? 0
    }
    
    private static func computeFitnessAge(vo2Max: Decimal?, chronologicalAge: Int?) -> Decimal? {
        guard let vo2Max = vo2Max else { return nil }
        let vo2 = NSDecimalNumber(decimal: vo2Max).doubleValue
        guard vo2 > 0 else { return nil }
        let age = Double(chronologicalAge ?? 40)
        // Simple heuristic: estimate fitness age by adjusting chronological age based on VO2 Max.
        // Higher VO2 Max reduces fitness age, lower VO2 Max increases it.
        let adjustment = (vo2 - 40.0) * -0.8 // each VO2 point above 40 reduces ~0.8 years
        let estimatedAge = max(18.0, age + adjustment)
        return Decimal(estimatedAge)
    }
    
    /// Fetch health metrics for a date range
    static func fetchHealthMetrics(userId: UUID, provider: String? = nil, startDate: Date, endDate: Date) async throws -> [HealthMetrics] {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]
        
        var query = Supa.client
            .from("health_metrics")
            .select()
            .eq("user_id", value: userId.uuidString)
            .gte("date", value: dateFormatter.string(from: startDate))
            .lte("date", value: dateFormatter.string(from: endDate))
        
        if let provider = provider {
            query = query.eq("provider", value: provider.lowercased())
        }
        
        let response = try await query
            .order("date", ascending: false)
            .execute()
        
        // Parse response data
        var dataArray: [[String: Any]]?
        
        if let parsed = try? JSONSerialization.jsonObject(with: response.data, options: []) as? [[String: Any]] {
            dataArray = parsed
        } else if let parsed = try? JSONSerialization.jsonObject(with: response.data, options: []) as? [String: Any] {
            dataArray = [parsed]
        }
        
        guard let dataArray = dataArray else {
            return []
        }
        
        let dateFormatter2 = ISO8601DateFormatter()
        dateFormatter2.formatOptions = [.withFullDate]
        
        return dataArray.compactMap { dict in
            guard let dateString = dict["date"] as? String,
                  let date = dateFormatter2.date(from: dateString),
                  let provider = dict["provider"] as? String else {
                return nil
            }
            
            return HealthMetrics(
                provider: provider,
                date: date,
                vo2Max: (dict["vo2_max"] as? Double).map { Decimal($0) },
                sleepScore: dict["sleep_score"] as? Int,
                recoveryScore: dict["recovery_score"] as? Int,
                restingHeartRate: dict["resting_heart_rate"] as? Int,
                weightKg: (dict["weight_kg"] as? Double).map { Decimal($0) },
                caloriesConsumed: dict["calories_consumed"] as? Int,
                ageYears: dict["age_years"] as? Int,
                fitnessAge: (dict["fitness_age"] as? Double).map { Decimal($0) }
            )
        }
    }
    
    // MARK: - Training Data
    
    /// Save training data (training plans, scheduled workouts) to Supabase
    static func saveTraining(userId: UUID, provider: String, trainingData: TrainingData) async throws -> UUID {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]
        
        let timestampFormatter = ISO8601DateFormatter()
        timestampFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let inferredActivityType = trainingData.activityTypeCode ?? ActivityTypeMapper.code(for: trainingData.workoutType)
        let inferredTimezoneOffset: Int? = {
            if let offset = trainingData.scheduledTimezoneOffsetMinutes {
                return offset
            }
            if let scheduledDate = trainingData.scheduledDate {
                return TimeZone.current.secondsFromGMT(for: scheduledDate) / 60
            }
            return nil
        }()
        
        // Create Codable struct for training
        let data = TrainingDataCodable(
            userId: userId.uuidString,
            provider: provider.lowercased(),
            trainingPlanId: trainingData.trainingPlanId,
            trainingPlanName: trainingData.trainingPlanName,
            workoutId: trainingData.workoutId,
            workoutName: trainingData.workoutName,
            workoutDescription: trainingData.workoutDescription,
            workoutType: trainingData.workoutType,
            activityTypeCode: inferredActivityType.rawValue,
            scheduledDate: trainingData.scheduledDate != nil ? dateFormatter.string(from: trainingData.scheduledDate!) : nil,
            scheduledTime: trainingData.scheduledTime,
            scheduledTimezoneOffsetMinutes: inferredTimezoneOffset,
            durationMinutes: trainingData.durationMinutes,
            distanceMeters: trainingData.distanceMeters,
            targetPaceSecondsPerKm: trainingData.targetPaceSecondsPerKm,
            targetHeartRateMin: trainingData.targetHeartRateMin,
            targetHeartRateMax: trainingData.targetHeartRateMax,
            targetCadence: trainingData.targetCadence,
            status: trainingData.status ?? "scheduled",
            completedDate: trainingData.completedDate != nil ? timestampFormatter.string(from: trainingData.completedDate!) : nil,
            completedDurationMinutes: trainingData.completedDurationMinutes,
            completedDistanceMeters: trainingData.completedDistanceMeters,
            notes: trainingData.notes
        )
        
        do {
            let response = try await Supa.client
                .from("training")
                .insert(data)
                .select()
                .single()
                .execute()
            
            // Parse response to get the ID
            if let json = try? JSONSerialization.jsonObject(with: response.data, options: []) as? [String: Any],
               let idString = json["id"] as? String,
               let id = UUID(uuidString: idString) {
                print("✅ Training data saved to Supabase: \(id)")
                return id
            }
            
            throw NSError(domain: "SupabaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse training ID from response"])
        } catch {
            print("❌ Error saving training data: \(error)")
            throw error
        }
    }
    
    /// Fetch training data for a user
    static func fetchTraining(userId: UUID, provider: String? = nil, startDate: Date? = nil, endDate: Date? = nil) async throws -> [TrainingData] {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]
        
        let timestampFormatter = ISO8601DateFormatter()
        timestampFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        var query = Supa.client
            .from("training")
            .select()
            .eq("user_id", value: userId.uuidString)
        
        if let provider = provider {
            query = query.eq("provider", value: provider.lowercased())
        }
        
        if let startDate = startDate {
            query = query.gte("scheduled_date", value: dateFormatter.string(from: startDate))
        }
        
        if let endDate = endDate {
            query = query.lte("scheduled_date", value: dateFormatter.string(from: endDate))
        }
        
        let response = try await query
            .order("scheduled_date", ascending: true)
            .order("scheduled_time", ascending: true)
            .execute()
        
        // Parse response data
        var dataArray: [[String: Any]]?
        
        if let parsed = try? JSONSerialization.jsonObject(with: response.data, options: []) as? [[String: Any]] {
            dataArray = parsed
        } else if let parsed = try? JSONSerialization.jsonObject(with: response.data, options: []) as? [String: Any] {
            dataArray = [parsed]
        }
        
        guard let dataArray = dataArray else {
            return []
        }
        
        return dataArray.compactMap { dict in
            guard let provider = dict["provider"] as? String else {
                return nil
            }
            
            let activityTypeCode = (dict["activity_type_code"] as? String).flatMap { ActivityTypeCode(rawValue: $0) }
            let timezoneOffsetMinutes = dict["scheduled_timezone_offset_minutes"] as? Int
            
            let scheduledDate: Date?
            if let dateString = dict["scheduled_date"] as? String {
                scheduledDate = dateFormatter.date(from: dateString)
            } else {
                scheduledDate = nil
            }
            
            let completedDate: Date?
            if let dateString = dict["completed_date"] as? String {
                completedDate = timestampFormatter.date(from: dateString)
            } else {
                completedDate = nil
            }
            
            return TrainingData(
                trainingPlanId: dict["training_plan_id"] as? String,
                trainingPlanName: dict["training_plan_name"] as? String,
                workoutId: dict["workout_id"] as? String,
                workoutName: dict["workout_name"] as? String,
                workoutDescription: dict["workout_description"] as? String,
                workoutType: dict["workout_type"] as? String,
                activityTypeCode: activityTypeCode,
                scheduledDate: scheduledDate,
                scheduledTime: dict["scheduled_time"] as? String,
                scheduledTimezoneOffsetMinutes: timezoneOffsetMinutes,
                durationMinutes: dict["duration_minutes"] as? Int,
                distanceMeters: (dict["distance_meters"] as? Double).map { Decimal($0) },
                targetPaceSecondsPerKm: dict["target_pace_seconds_per_km"] as? Int,
                targetHeartRateMin: dict["target_heart_rate_min"] as? Int,
                targetHeartRateMax: dict["target_heart_rate_max"] as? Int,
                targetCadence: dict["target_cadence"] as? Int,
                status: dict["status"] as? String,
                completedDate: completedDate,
                completedDurationMinutes: dict["completed_duration_minutes"] as? Int,
                completedDistanceMeters: (dict["completed_distance_meters"] as? Double).map { Decimal($0) },
                notes: dict["notes"] as? String
            )
        }
    }
    
    static func fetchRacePlanTrackPoints(racePlanId: UUID) async throws -> [TrackPoint] {
        let response = try await Supa.client
            .from("race_plans")
            .select("gpx_file_data")
            .eq("id", value: racePlanId.uuidString)
            .single()
            .execute()
        
        guard let json = try? JSONSerialization.jsonObject(with: response.data, options: []) as? [String: Any],
              let gpxFileData = json["gpx_file_data"] as? String else {
            return []
        }
        
        let data: Data
        
        // Check if it's a URL (new storage format) or base64 (old format)
        if gpxFileData.hasPrefix("http://") || gpxFileData.hasPrefix("https://") {
            // Download from Supabase Storage
            print("📥 Downloading GPX file from storage: \(gpxFileData)")
            guard let url = URL(string: gpxFileData) else {
                print("❌ Invalid GPX file URL")
                return []
            }
            
            do {
                let (fileData, _) = try await URLSession.shared.data(from: url)
                data = fileData
                print("✅ GPX file downloaded: \(data.count) bytes")
            } catch {
                print("❌ Error downloading GPX file: \(error)")
                return []
            }
        } else {
            // Decode base64 (backwards compatibility with old format)
            guard let decodedData = Data(base64Encoded: gpxFileData) else {
                print("❌ Invalid base64 GPX file data")
                return []
            }
            data = decodedData
            print("✅ GPX file decoded from base64: \(data.count) bytes")
        }
        
        let parser = GPXParser()
        let rawPoints = parser.parse(data: data)
        return makeTrackPoints(from: rawPoints)
    }
    
    static func deleteRacePlan(racePlanId: UUID) async throws {
        let params: [String: String] = ["p_race_plan_id": racePlanId.uuidString]
        try await Supa.client
            .rpc("delete_race_plan_cascade", params: params)
            .execute()
    }
}

// MARK: - Supporting Models

// MARK: - Codable Data Structures for Supabase

struct ProfileData: Codable {
    let id: String
    let firstName: String
    let lastName: String
    let birthDate: String
    let gender: String
    let runningDistances: [String]
    let experienceLevel: String
    let hasCompletedOnboarding: Bool
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case firstName = "first_name"
        case lastName = "last_name"
        case birthDate = "birth_date"
        case gender
        case runningDistances = "running_distances"
        case experienceLevel = "experience_level"
        case hasCompletedOnboarding = "has_completed_onboarding"
        case updatedAt = "updated_at"
    }
}

struct OnboardingStatusUpdate: Codable {
    let hasCompletedOnboarding: Bool
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case hasCompletedOnboarding = "has_completed_onboarding"
        case updatedAt = "updated_at"
    }
}

struct RacePlanData: Codable {
    let userId: String
    let title: String
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case title
        case createdAt = "created_at"
    }
}

struct RacePlanUpdateData: Codable {
    let gpxFileName: String
    let gpxFileData: String
    let updatedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case gpxFileName = "gpx_file_name"
        case gpxFileData = "gpx_file_data"
        case updatedAt = "updated_at"
    }
    
    init(gpxFileName: String, gpxFileData: String, updatedAt: String? = nil) {
        self.gpxFileName = gpxFileName
        self.gpxFileData = gpxFileData
        self.updatedAt = updatedAt
    }
}

struct RacePlanSegmentData: Codable {
    let racePlanId: String
    let index: Int
    let distanceM: Double
    let targetPaceSPerKm: Int
    let notes: String?
    let services: [AidStationServicePayload]
    let segmentDistanceM: Double
    let elevationGainM: Double
    let elevationLossM: Double
    let estimatedTimeSeconds: Double
    let averageHeartRate: Double?
    
    enum CodingKeys: String, CodingKey {
        case racePlanId = "race_plan_id"
        case index
        case distanceM = "distance_m"
        case targetPaceSPerKm = "target_pace_s_per_km"
        case notes
        case services
        case segmentDistanceM = "segment_distance_m"
        case elevationGainM = "elevation_gain_m"
        case elevationLossM = "elevation_loss_m"
        case estimatedTimeSeconds = "estimated_time_seconds"
        case averageHeartRate = "average_heart_rate"
    }
}

struct FuelEventData: Codable {
    let racePlanId: String
    let atMinute: Int
    let carbsG: Int
    let notes: String?
    
    enum CodingKeys: String, CodingKey {
        case racePlanId = "race_plan_id"
        case atMinute = "at_minute"
        case carbsG = "carbs_g"
        case notes
    }
}

// Note: OAuthConnectionData struct removed - token_secret column doesn't exist in database
// Using OAuthConnectionInsert defined in saveOAuthConnection() instead

struct OAuthConnection {
    let provider: String
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date?
}

struct WorkoutData: Codable {
    let userId: String
    let provider: String
    let providerActivityId: String
    let name: String?
    let startTime: String
    let elapsedSeconds: Int
    let movingSeconds: Int?
    let distanceM: Double
    let elevationGainM: Double
    let avgHR: Int?
    let maxHR: Int?
    let avgPaceSPerKm: Int?
    let activityTypeCode: String
    let startTimezoneOffsetMinutes: Int?
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case provider
        case providerActivityId = "provider_activity_id"
        case name
        case startTime = "start_time"
        case elapsedSeconds = "elapsed_seconds"
        case movingSeconds = "moving_seconds"
        case distanceM = "distance_m"
        case elevationGainM = "elevation_gain_m"
        case avgHR = "avg_hr"
        case maxHR = "max_hr"
        case avgPaceSPerKm = "avg_pace_s_per_km"
        case activityTypeCode = "activity_type_code"
        case startTimezoneOffsetMinutes = "start_timezone_offset_minutes"
    }
}

struct SampleData: Codable {
    let workoutId: String
    let tS: Int
    let lat: Double?
    let lon: Double?
    let altM: Double?
    let hr: Int?
    let cadence: Int?
    let paceSPerKm: Int?
    let airTemperatureC: Double?
    let speedMPerS: Double?
    let stepsPerMinute: Int?
    
    enum CodingKeys: String, CodingKey {
        case workoutId = "workout_id"
        case tS = "t_s"
        case lat
        case lon
        case altM = "alt_m"
        case hr
        case cadence
        case paceSPerKm = "pace_s_per_km"
        case airTemperatureC = "air_temperature_c"
        case speedMPerS = "speed_m_per_s"
        case stepsPerMinute = "steps_per_minute"
    }
}

struct LapData: Codable {
    let workoutId: String
    let index: Int
    let startOffsetS: Int
    let durationS: Int
    let distanceM: Double
    let elevationGainM: Double
    let avgHR: Int?
    let avgPaceSPerKm: Int?
    
    enum CodingKeys: String, CodingKey {
        case workoutId = "workout_id"
        case index
        case startOffsetS = "start_offset_s"
        case durationS = "duration_s"
        case distanceM = "distance_m"
        case elevationGainM = "elevation_gain_m"
        case avgHR = "avg_hr"
        case avgPaceSPerKm = "avg_pace_s_per_km"
    }
}

struct HealthMetricsData: Codable {
    let userId: String
    let provider: String
    let date: String // ISO 8601 date format (YYYY-MM-DD)
    let vo2Max: Decimal?
    let sleepScore: Int?
    let recoveryScore: Int?
    let restingHeartRate: Int?
    let weightKg: Decimal?
    let caloriesConsumed: Int?
    let ageYears: Int?
    let fitnessAge: Decimal?
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case provider
        case date
        case vo2Max = "vo2_max"
        case sleepScore = "sleep_score"
        case recoveryScore = "recovery_score"
        case restingHeartRate = "resting_heart_rate"
        case weightKg = "weight_kg"
        case caloriesConsumed = "calories_consumed"
        case ageYears = "age_years"
        case fitnessAge = "fitness_age"
    }
}

struct WorkoutSummary: Codable {
    let id: UUID
    let distanceM: Double?
    let elapsedSeconds: Int?
    let avgHR: Int?
    let maxHR: Int?
    let calories: Int?
    let startTime: Date?
}

struct WorkoutSample {
    let timeOffsetSeconds: Int
    let paceSecondsPerKm: Int?
    let heartRate: Int?
    let altitudeMeters: Double?
    let cadence: Int?
}

struct RacePlanResponse: Codable {
    let id: UUID
    let userId: String
    let title: String
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title
        case createdAt = "created_at"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Handle UUID - can be string or UUID
        if let idString = try? container.decode(String.self, forKey: .id) {
            guard let uuid = UUID(uuidString: idString) else {
                throw DecodingError.dataCorruptedError(forKey: .id, in: container, debugDescription: "Invalid UUID string")
            }
            self.id = uuid
        } else {
            self.id = try container.decode(UUID.self, forKey: .id)
        }
        
        userId = try container.decode(String.self, forKey: .userId)
        title = try container.decode(String.self, forKey: .title)
        createdAt = try container.decode(String.self, forKey: .createdAt)
    }
}

struct RacePlanSummary: Identifiable, Codable {
    let id: UUID
    let title: String
    let createdAt: Date
    let updatedAt: Date
}

// MARK: - Training Data Models

struct TrainingData {
    let trainingPlanId: String?
    let trainingPlanName: String?
    let workoutId: String?
    let workoutName: String?
    let workoutDescription: String?
    let workoutType: String?
    let activityTypeCode: ActivityTypeCode?
    let scheduledDate: Date?
    let scheduledTime: String?
    let scheduledTimezoneOffsetMinutes: Int?
    let durationMinutes: Int?
    let distanceMeters: Decimal?
    let targetPaceSecondsPerKm: Int?
    let targetHeartRateMin: Int?
    let targetHeartRateMax: Int?
    let targetCadence: Int?
    let status: String?
    let completedDate: Date?
    let completedDurationMinutes: Int?
    let completedDistanceMeters: Decimal?
    let notes: String?
}

struct TrainingDataCodable: Codable {
    let userId: String
    let provider: String
    let trainingPlanId: String?
    let trainingPlanName: String?
    let workoutId: String?
    let workoutName: String?
    let workoutDescription: String?
    let workoutType: String?
    let activityTypeCode: String?
    let scheduledDate: String?
    let scheduledTime: String?
    let scheduledTimezoneOffsetMinutes: Int?
    let durationMinutes: Int?
    let distanceMeters: Decimal?
    let targetPaceSecondsPerKm: Int?
    let targetHeartRateMin: Int?
    let targetHeartRateMax: Int?
    let targetCadence: Int?
    let status: String
    let completedDate: String?
    let completedDurationMinutes: Int?
    let completedDistanceMeters: Decimal?
    let notes: String?
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case provider
        case trainingPlanId = "training_plan_id"
        case trainingPlanName = "training_plan_name"
        case workoutId = "workout_id"
        case workoutName = "workout_name"
        case workoutDescription = "workout_description"
        case workoutType = "workout_type"
        case activityTypeCode = "activity_type_code"
        case scheduledDate = "scheduled_date"
        case scheduledTime = "scheduled_time"
        case scheduledTimezoneOffsetMinutes = "scheduled_timezone_offset_minutes"
        case durationMinutes = "duration_minutes"
        case distanceMeters = "distance_meters"
        case targetPaceSecondsPerKm = "target_pace_seconds_per_km"
        case targetHeartRateMin = "target_heart_rate_min"
        case targetHeartRateMax = "target_heart_rate_max"
        case targetCadence = "target_cadence"
        case status
        case completedDate = "completed_date"
        case completedDurationMinutes = "completed_duration_minutes"
        case completedDistanceMeters = "completed_distance_meters"
        case notes
    }
}

struct RacePlanSegment: Identifiable, Codable {
    let id: UUID
    let racePlanId: UUID
    let index: Int
    let distanceM: Double
    let targetPaceSPerKm: Int
    let notes: String?
    let services: [AidStationServicePayload]
    let segmentDistanceM: Double
    let elevationGainM: Double
    let elevationLossM: Double
    let estimatedTimeSeconds: Double
    let averageHeartRate: Double?
}

struct SupabaseFuelEvent: Identifiable {
    let id: UUID
    let racePlanId: UUID
    let atMinute: Int
    let carbsG: Int
    let notes: String?
}

struct SupabaseFuelType: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let name: String
    let category: String
    let carbs: Int
    let sodium: Int
    let isCustom: Bool
}

struct FuelTypeData: Codable {
    let userId: String
    let name: String
    let category: String
    let carbs: Int
    let sodium: Int
    let isCustom: Bool
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case name
        case category
        case carbs
        case sodium
        case isCustom = "is_custom"
    }
}

struct FuelTypeUpdateData: Codable {
    let name: String
    let category: String
    let carbs: Int
    let sodium: Int
}

// MARK: - Garmin Activities & Health Data

/// Garmin Activity model for reading from Supabase database
struct GarminActivityFromDB: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let garminActivityId: String
    let activityType: String?
    let activityName: String?
    let startTimeSeconds: Int64
    let durationSeconds: Int?
    let distanceMeters: Double?
    let elevationGainMeters: Int?
    let elevationLossMeters: Int?
    let avgHeartRate: Int?
    let maxHeartRate: Int?
    let avgPaceSecondsPerKm: Double?
    let calories: Int?
    let deviceName: String?
    let createdAt: Date?
    let updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case garminActivityId = "garmin_activity_id"
        case activityType = "activity_type"
        case activityName = "activity_name"
        case startTimeSeconds = "start_time_seconds"
        case durationSeconds = "duration_seconds"
        case distanceMeters = "distance_meters"
        case elevationGainMeters = "elevation_gain_meters"
        case elevationLossMeters = "elevation_loss_meters"
        case avgHeartRate = "avg_heart_rate"
        case maxHeartRate = "max_heart_rate"
        case avgPaceSecondsPerKm = "avg_pace_seconds_per_km"
        case calories
        case deviceName = "device_name"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    var startDate: Date {
        Date(timeIntervalSince1970: TimeInterval(startTimeSeconds))
    }
    
    var distanceKm: Double {
        (distanceMeters ?? 0) / 1000.0
    }
    
    var durationHours: Double {
        Double(durationSeconds ?? 0) / 3600.0
    }
}

/// Garmin Activity Sample (GPS track point)
struct GarminActivitySample: Identifiable, Codable {
    let id: UUID
    let activityId: UUID
    let timestampSeconds: Int64
    let latitude: Double?
    let longitude: Double?
    let elevationMeters: Double?
    let heartRate: Int?
    let paceSecondsPerKm: Double?
    
    enum CodingKeys: String, CodingKey {
        case id
        case activityId = "activity_id"
        case timestampSeconds = "timestamp_seconds"
        case latitude
        case longitude
        case elevationMeters = "elevation_meters"
        case heartRate = "heart_rate"
        case paceSecondsPerKm = "pace_seconds_per_km"
    }
    
    var timestamp: Date {
        Date(timeIntervalSince1970: TimeInterval(timestampSeconds))
    }
}

/// Garmin Health Metrics model
struct GarminHealthMetrics: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let garminUserId: String
    let timestamp: Date
    let fitnessAge: Int?
    let vo2Max: Double?
    let rawData: [String: Any]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case garminUserId = "garmin_user_id"
        case timestamp
        case fitnessAge = "fitness_age"
        case vo2Max = "vo2_max"
        case rawData = "raw_data"
    }
    
    // Custom initializer for manual creation
    init(
        id: UUID,
        userId: UUID,
        garminUserId: String,
        timestamp: Date,
        fitnessAge: Int?,
        vo2Max: Double?,
        rawData: [String: Any]?
    ) {
        self.id = id
        self.userId = userId
        self.garminUserId = garminUserId
        self.timestamp = timestamp
        self.fitnessAge = fitnessAge
        self.vo2Max = vo2Max
        self.rawData = rawData
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        userId = try container.decode(UUID.self, forKey: .userId)
        garminUserId = try container.decode(String.self, forKey: .garminUserId)
        
        let timestampString = try container.decode(String.self, forKey: .timestamp)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        timestamp = formatter.date(from: timestampString) ?? Date()
        
        fitnessAge = try container.decodeIfPresent(Int.self, forKey: .fitnessAge)
        vo2Max = try container.decodeIfPresent(Double.self, forKey: .vo2Max)
        
        // Decode raw_data as JSON
        if let rawDataString = try? container.decode(String.self, forKey: .rawData),
           let data = rawDataString.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            rawData = json
        } else {
            rawData = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(userId, forKey: .userId)
        try container.encode(garminUserId, forKey: .garminUserId)
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        try container.encode(formatter.string(from: timestamp), forKey: .timestamp)
        
        try container.encodeIfPresent(fitnessAge, forKey: .fitnessAge)
        try container.encodeIfPresent(vo2Max, forKey: .vo2Max)
        
        if let rawData = rawData,
           let jsonData = try? JSONSerialization.data(withJSONObject: rawData),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            try container.encode(jsonString, forKey: .rawData)
        }
    }
}

extension SupabaseService {
    // MARK: - Garmin Activities
    
    /// Fetch Garmin activities from Supabase for a date range (with offline caching)
    static func fetchGarminActivities(
        userId: UUID,
        startDate: Date? = nil,
        endDate: Date? = nil,
        limit: Int = 100
    ) async throws -> [GarminActivityFromDB] {
        // Check if offline - return cached data
        if !NetworkMonitor.shared.isConnected {
            print("📦 Offline: Loading Garmin activities from cache")
            if let cached = DataCache.shared.loadArray(GarminActivityFromDB.self, key: .garminActivities, userId: userId) {
                // Filter by date range if provided
                var filtered = cached
                if let startDate = startDate {
                    let startSeconds = Int(startDate.timeIntervalSince1970)
                    filtered = filtered.filter { $0.startTimeSeconds >= startSeconds }
                }
                if let endDate = endDate {
                    let endSeconds = Int(endDate.timeIntervalSince1970)
                    filtered = filtered.filter { $0.startTimeSeconds <= endSeconds }
                }
                print("✅ Loaded \(filtered.count) Garmin activities from cache")
                return Array(filtered.prefix(limit))
            }
            throw NSError(domain: "SupabaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No internet connection and no cached data available"])
        }
        
        var query = Supa.client
            .from("garmin_activities")
            .select("*")
            .eq("user_id", value: userId.uuidString)
        
        // Apply filters before ordering/limiting
        if let startDate = startDate {
            let startSeconds = Int(startDate.timeIntervalSince1970)
            query = query.gte("start_time_seconds", value: startSeconds)
        }
        
        if let endDate = endDate {
            let endSeconds = Int(endDate.timeIntervalSince1970)
            query = query.lte("start_time_seconds", value: endSeconds)
        }
        
        // Apply ordering and limit after filters
        let response = try await query
            .order("start_time_seconds", ascending: false)
            .limit(limit)
            .execute()
        
        // Parse response
        guard let dataArray = try? JSONSerialization.jsonObject(with: response.data) as? [[String: Any]] else {
            // If fetch fails but we have cache, return cache
            if let cached = DataCache.shared.loadArray(GarminActivityFromDB.self, key: .garminActivities, userId: userId) {
                print("⚠️ Fetch failed, returning cached data")
                return cached
            }
            return []
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        let activities = dataArray.compactMap { dict -> GarminActivityFromDB? in
            guard let jsonData = try? JSONSerialization.data(withJSONObject: dict) else {
                return nil
            }
            return try? decoder.decode(GarminActivityFromDB.self, from: jsonData)
        }
        
        // Cache the fetched data
        DataCache.shared.saveArray(activities, key: .garminActivities, userId: userId)
        print("✅ Fetched and cached \(activities.count) Garmin activities")
        
        return activities
    }
    
    /// Fetch a single Garmin activity by ID
    static func fetchGarminActivity(activityId: UUID) async throws -> GarminActivityFromDB? {
        let response = try await Supa.client
            .from("garmin_activities")
            .select("*")
            .eq("id", value: activityId.uuidString)
            .single()
            .execute()
        
        guard let dict = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any],
              let jsonData = try? JSONSerialization.data(withJSONObject: dict) else {
            return nil
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try? decoder.decode(GarminActivityFromDB.self, from: jsonData)
    }
    
    /// Fetch GPS samples (track points) for a Garmin activity
    static func fetchGarminActivitySamples(activityId: UUID) async throws -> [GarminActivitySample] {
        let response = try await Supa.client
            .from("garmin_activity_samples")
            .select("*")
            .eq("activity_id", value: activityId.uuidString)
            .order("timestamp_seconds", ascending: true)
            .execute()
        
        guard let dataArray = try? JSONSerialization.jsonObject(with: response.data) as? [[String: Any]] else {
            return []
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        return dataArray.compactMap { dict in
            guard let jsonData = try? JSONSerialization.data(withJSONObject: dict) else {
                return nil
            }
            return try? decoder.decode(GarminActivitySample.self, from: jsonData)
        }
    }
    
    // MARK: - Garmin Health Metrics
    
    /// Fetch Garmin health metrics from Supabase for a date range
    /// Note: Data is stored with metric_date (date string) and includes:
    /// - avg_heart_rate, max_heart_rate, steps, active_calories
    static func fetchGarminHealthMetrics(
        userId: UUID,
        startDate: Date,
        endDate: Date
    ) async throws -> [GarminHealthMetrics] {
        // Format dates as YYYY-MM-DD strings to match metric_date column
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        
        let startDateString = dateFormatter.string(from: startDate)
        let endDateString = dateFormatter.string(from: endDate)
        
        let response = try await Supa.client
            .from("garmin_health_metrics")
            .select("*")
            .eq("user_id", value: userId.uuidString)
            .gte("metric_date", value: startDateString)
            .lte("metric_date", value: endDateString)
            .order("metric_date", ascending: false)
            .execute()
        
        guard let dataArray = try? JSONSerialization.jsonObject(with: response.data) as? [[String: Any]] else {
            return []
        }
        
        // Manual decoding - data is stored with metric_date, not timestamp
        return dataArray.compactMap { dict -> GarminHealthMetrics? in
            guard let idString = dict["id"] as? String,
                  let id = UUID(uuidString: idString),
                  let userIdString = dict["user_id"] as? String,
                  let userId = UUID(uuidString: userIdString) else {
                return nil
            }
            
            // Parse metric_date (stored as YYYY-MM-DD string)
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            dateFormatter.timeZone = TimeZone(identifier: "UTC")
            
            let timestamp: Date
            if let metricDateString = dict["metric_date"] as? String,
               let date = dateFormatter.date(from: metricDateString) {
                timestamp = date
            } else if let updatedAtString = dict["updated_at"] as? String {
                // Fallback to updated_at if metric_date is missing
                let isoFormatter = ISO8601DateFormatter()
                isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                timestamp = isoFormatter.date(from: updatedAtString) ?? Date()
            } else {
                return nil
            }
            
            // Get garmin_user_id if available (may not be in activity-based metrics)
            let garminUserId = dict["garmin_user_id"] as? String ?? ""
            
            // These fields may not be present in activity-based health metrics
            let fitnessAge = dict["fitness_age"] as? Int
            let vo2Max = dict["vo2_max"] as? Double
            
            // Build raw_data from available fields
            var rawData: [String: Any] = [:]
            if let avgHR = dict["avg_heart_rate"] as? Int { rawData["avg_heart_rate"] = avgHR }
            if let maxHR = dict["max_heart_rate"] as? Int { rawData["max_heart_rate"] = maxHR }
            if let steps = dict["steps"] as? Int { rawData["steps"] = steps }
            if let calories = dict["active_calories"] as? Int { rawData["active_calories"] = calories }
            
            // Also check if raw_data already exists
            if let rawDataValue = dict["raw_data"] {
                if let dictValue = rawDataValue as? [String: Any] {
                    rawData.merge(dictValue) { (_, new) in new }
                } else if let stringValue = rawDataValue as? String,
                          let data = stringValue.data(using: .utf8),
                          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    rawData.merge(json) { (_, new) in new }
                }
            }
            
            return GarminHealthMetrics(
                id: id,
                userId: userId,
                garminUserId: garminUserId,
                timestamp: timestamp,
                fitnessAge: fitnessAge,
                vo2Max: vo2Max,
                rawData: rawData.isEmpty ? nil : rawData
            )
        }
    }
    
    /// Fetch latest Garmin health metrics
    static func fetchLatestGarminHealthMetrics(userId: UUID) async throws -> GarminHealthMetrics? {
        let response = try await Supa.client
            .from("garmin_health_metrics")
            .select("*")
            .eq("user_id", value: userId.uuidString)
            .order("metric_date", ascending: false)
            .limit(1)
            .execute()
        
        guard let dataArray = try? JSONSerialization.jsonObject(with: response.data) as? [[String: Any]],
              let dict = dataArray.first else {
            return nil
        }
        
        // Same parsing logic as fetchGarminHealthMetrics
        guard let idString = dict["id"] as? String,
              let id = UUID(uuidString: idString),
              let userIdString = dict["user_id"] as? String,
              let userId = UUID(uuidString: userIdString) else {
            return nil
        }
        
        // Parse metric_date (stored as YYYY-MM-DD string)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        
        let timestamp: Date
        if let metricDateString = dict["metric_date"] as? String,
           let date = dateFormatter.date(from: metricDateString) {
            timestamp = date
        } else if let updatedAtString = dict["updated_at"] as? String {
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            timestamp = isoFormatter.date(from: updatedAtString) ?? Date()
        } else {
            return nil
        }
        
        let garminUserId = dict["garmin_user_id"] as? String ?? ""
        let fitnessAge = dict["fitness_age"] as? Int
        let vo2Max = dict["vo2_max"] as? Double
        
        // Build raw_data from available fields
        var rawData: [String: Any] = [:]
        if let avgHR = dict["avg_heart_rate"] as? Int { rawData["avg_heart_rate"] = avgHR }
        if let maxHR = dict["max_heart_rate"] as? Int { rawData["max_heart_rate"] = maxHR }
        if let steps = dict["steps"] as? Int { rawData["steps"] = steps }
        if let calories = dict["active_calories"] as? Int { rawData["active_calories"] = calories }
        
        if let rawDataValue = dict["raw_data"] {
            if let dictValue = rawDataValue as? [String: Any] {
                rawData.merge(dictValue) { (_, new) in new }
            } else if let stringValue = rawDataValue as? String,
                      let data = stringValue.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                rawData.merge(json) { (_, new) in new }
            }
        }
        
        return GarminHealthMetrics(
            id: id,
            userId: userId,
            garminUserId: garminUserId,
            timestamp: timestamp,
            fitnessAge: fitnessAge,
            vo2Max: vo2Max,
            rawData: rawData.isEmpty ? nil : rawData
        )
    }
    
    /// Check if user has Garmin connected
    static func hasGarminConnection(userId: UUID) async throws -> Bool {
        let response = try await Supa.client
            .from("garmin_connections")
            .select("id")
            .eq("user_id", value: userId.uuidString)
            .eq("permission_revoked", value: false)
            .limit(1)
            .execute()
        
        guard let dataArray = try? JSONSerialization.jsonObject(with: response.data) as? [[String: Any]] else {
            return false
        }
        
        return !dataArray.isEmpty
    }
}

struct AidStationServicePayload: Codable {
    let type: String
    let isAvailable: Bool
    
    init(type: String, isAvailable: Bool) {
        self.type = type
        self.isAvailable = isAvailable
    }
    
    init(service: AidService) {
        self.init(type: service.type.rawValue, isAvailable: service.isAvailable)
    }
    
    func toAidService() -> AidService? {
        guard let serviceType = AidService.ServiceType(rawValue: type) else { return nil }
        return AidService(type: serviceType, isAvailable: isAvailable)
    }
}

struct TrackPoint: Codable {
    let lat: Double
    let lon: Double
    let ele: Double
    let distFromStart: Double
    let hr: Int?
}

struct AidStationSegmentMetrics: Codable {
    let segmentDistanceM: Double
    let elevationGainM: Double
    let elevationLossM: Double
    let estimatedTimeSeconds: Double
    let averageHeartRate: Double?
    let targetHeartRate: Double? // Calculated target HR based on physiological maxHR and race fraction
}

struct RacePlanTitleUpdate: Codable {
    let title: String
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case title
        case updatedAt = "updated_at"
    }
}

struct RacePlanDateUpdate: Codable {
    let raceDate: String
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case raceDate = "race_date"
        case updatedAt = "updated_at"
    }
}

private struct DefaultFuelType {
    let name: String
    let category: String
    let carbs: Int
    let sodium: Int
}

private let defaultFuelCatalog: [DefaultFuelType] = [
    DefaultFuelType(name: "Tailwind Endurance", category: "Carb Drink Mix", carbs: 50, sodium: 200),
    DefaultFuelType(name: "Maurten Gel", category: "Energy Gel", carbs: 25, sodium: 40),
    DefaultFuelType(name: "Clif Bar", category: "Energy Bar", carbs: 30, sodium: 150),
    DefaultFuelType(name: "Banana", category: "Fruit", carbs: 30, sodium: 1),
    DefaultFuelType(name: "GU Chews", category: "Chew Pack", carbs: 20, sodium: 60),
    DefaultFuelType(name: "Pretzels", category: "Salty Snack", carbs: 25, sodium: 400)
]
