import Foundation

/// Service for syncing race plans to Polar Flow as structured workouts
/// Converts pacing segments and fueling stations into Polar workout format
@MainActor
final class PolarWorkoutSyncService {
    private let userId: UUID
    private let supabaseAnonKey: String
    private let edgeFunctionURL: String
    
    init(userId: UUID) {
        self.userId = userId
        // Get Supabase config - these should be available via Config
        self.supabaseAnonKey = Config.supabaseAnonKey
        self.edgeFunctionURL = "\(Config.edgeFunctionsBaseURL)/polar-workout-create"
    }
    
    // MARK: - Main Sync Function
    
    /// Sync a race plan to Polar Flow as a structured workout
    /// - Parameters:
    ///   - workoutName: Name of the workout (race strategy name)
    ///   - pacingSegments: Array of pacing segments from race calendar
    ///   - fuelingStations: Array of fueling stations (aligned with pacing segments by index)
    ///   - raceDate: Optional race date for scheduling
    /// - Returns: Workout ID from Polar Flow
    func syncRacePlanToPolar(
        workoutName: String,
        pacingSegments: [PacingSegment],
        fuelingStations: [FuelingStation],
        raceDate: Date?
    ) async throws -> String {
        print("🔄 Starting Polar workout sync...")
        print("📋 Workout Name: \(workoutName)")
        print("📋 Pacing Segments: \(pacingSegments.count)")
        print("📋 Fueling Stations: \(fuelingStations.count)")
        
        // Validate inputs
        guard !pacingSegments.isEmpty else {
            throw PolarWorkoutSyncError.emptyPacingSegments
        }
        
        // Convert race plan to Polar workout format
        let workoutJSON = try convertToPolarWorkout(
            workoutName: workoutName,
            pacingSegments: pacingSegments,
            fuelingStations: fuelingStations,
            raceDate: raceDate
        )
        
        // Create workout in Polar Flow
        let workoutId = try await createWorkoutInPolar(
            workoutJSON: workoutJSON
        )
        
        print("✅ Workout created successfully with ID: \(workoutId)")
        return workoutId
    }
    
    // MARK: - Edge Function Integration
    
    /// Create workout in Polar Flow via Edge Function (handles token refresh automatically)
    private func createWorkoutInPolar(
        workoutJSON: [String: Any]
    ) async throws -> String {
        // Call Supabase Edge Function which handles token refresh and API call
        let url = URL(string: edgeFunctionURL)!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        
        // Prepare request body
        let requestBody: [String: Any] = [
            "user_id": userId.uuidString,
            "workout": workoutJSON
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody, options: [])
        
        print("📡 Sending workout creation request to Edge Function...")
        if let jsonString = String(data: request.httpBody!, encoding: .utf8) {
            print("📋 Request body: \(jsonString)")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PolarWorkoutSyncError.invalidResponse
        }
        
        print("📡 Edge Function response: \(httpResponse.statusCode)")
        
        // Handle different response codes
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Workout creation failed: \(errorString)")
            
            // Try to parse error details
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = errorJson["error"] as? String {
                if httpResponse.statusCode == 401 {
                    throw PolarWorkoutSyncError.unauthorized
                } else if httpResponse.statusCode == 403 {
                    throw PolarWorkoutSyncError.forbidden
                } else {
                    throw PolarWorkoutSyncError.apiError(message: errorMessage)
                }
            } else {
                throw PolarWorkoutSyncError.apiError(message: "HTTP \(httpResponse.statusCode): \(errorString)")
            }
        }
        
        // Parse response to get workout ID
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PolarWorkoutSyncError.invalidResponse
        }
        
        // Extract workout ID from Edge Function response
        if let workoutId = json["workoutId"] as? String {
            return workoutId
        } else if let workoutId = json["workoutId"] as? Int {
            return String(workoutId)
        } else if let workout = json["workout"] as? [String: Any],
                  let workoutId = workout["workoutId"] as? String {
            return workoutId
        } else {
            // If no workout ID in response, return a success indicator
            print("⚠️ No workout ID in response, but request succeeded")
            return "success"
        }
    }
    
    // MARK: - Workout Format Conversion
    
    /// Convert race plan data to Polar workout JSON format
    /// Note: Polar API structure may need adjustment based on actual API documentation
    private func convertToPolarWorkout(
        workoutName: String,
        pacingSegments: [PacingSegment],
        fuelingStations: [FuelingStation],
        raceDate: Date?
    ) throws -> [String: Any] {
        var workoutSteps: [[String: Any]] = []
        
        // Process each pacing segment and its corresponding fueling station
        var stepOrder = 1
        for (index, segment) in pacingSegments.enumerated() {
            // Add pacing segment as run step
            var runStep = try createRunStep(from: segment)
            runStep["stepOrder"] = stepOrder
            workoutSteps.append(runStep)
            stepOrder += 1
            
            // Add fueling station as rest step (if available)
            if index < fuelingStations.count {
                var fuelingStep = createFuelingStep(from: fuelingStations[index])
                fuelingStep["stepOrder"] = stepOrder
                workoutSteps.append(fuelingStep)
                stepOrder += 1
            }
        }
        
        // Build workout JSON structure for Polar API
        // Note: This structure may need adjustment based on actual Polar API documentation
        let workout: [String: Any] = [
            "name": workoutName.isEmpty ? "Race Workout" : workoutName,
            "description": "Race strategy synced from HYKA",
            "sport": "RUNNING",
            "steps": workoutSteps
        ]
        
        return workout
    }
    
    /// Create a run step from a pacing segment
    private func createRunStep(from segment: PacingSegment) throws -> [String: Any] {
        // Validate segment distance
        let distanceKm = max(segment.segmentDistance, 0.1)
        let distanceMeters = Int(distanceKm * 1000)
        
        // Parse pace (in min/km format, e.g., "5:57 m/km")
        guard let paceSecondsPerKm = parsePaceString(segment.estimatedPace) else {
            throw PolarWorkoutSyncError.invalidPaceFormat(segment.estimatedPace)
        }
        
        // Calculate pace range (±5 seconds per km)
        let paceMinSecondsPerKm = max(paceSecondsPerKm - 5, 1)
        let paceMaxSecondsPerKm = paceSecondsPerKm + 5
        
        // Convert to m/s for API
        let paceMinMetersPerSecond = 1000.0 / Double(paceMaxSecondsPerKm)
        let paceMaxMetersPerSecond = 1000.0 / Double(paceMinSecondsPerKm)
        
        print("📊 Pace conversion: \(segment.estimatedPace) -> \(paceSecondsPerKm)s/km -> \(String(format: "%.3f", paceMinMetersPerSecond)) m/s")
        
        // Build step for Polar API
        var step: [String: Any] = [
            "type": "interval",
            "stepOrder": 0, // Will be set by caller
            "intensity": "active",
            "description": "Segment: \(segment.from) → \(segment.to)",
            "duration": [
                "type": "distance",
                "value": distanceMeters,
                "unit": "meter"
            ],
            "target": [
                "type": "pace",
                "low": paceMinMetersPerSecond,
                "high": paceMaxMetersPerSecond,
                "unit": "m/s"
            ]
        ]
        
        // Add heart rate information to description
        if !segment.heartRate.isEmpty {
            if let currentDesc = step["description"] as? String {
                step["description"] = "\(currentDesc)\nTarget HR: \(segment.heartRate)"
            }
        }
        
        return step
    }
    
    /// Create a fueling step from a fueling station
    private func createFuelingStep(from station: FuelingStation) -> [String: Any] {
        let description = """
        STATION: \(station.name)
        DRINK: \(station.water)ml
        CARBS: \(station.carbs)g
        SODIUM: \(station.sodium)mg
        """
        
        return [
            "type": "rest",
            "stepOrder": 0, // Will be set by caller
            "intensity": "rest",
            "description": description,
            "duration": [
                "type": "open" // Manual lap button press
            ]
        ]
    }
    
    // MARK: - Parsing Utilities
    
    /// Parse pace string to seconds per km
    func parsePaceString(_ pace: String) -> Int? {
        var cleaned = pace.trimmingCharacters(in: .whitespaces).lowercased()
        
        cleaned = cleaned.replacingOccurrences(of: " m/km", with: "", options: .caseInsensitive)
        cleaned = cleaned.replacingOccurrences(of: " m/min", with: "", options: .caseInsensitive)
        cleaned = cleaned.replacingOccurrences(of: "/km", with: "", options: .caseInsensitive)
        cleaned = cleaned.replacingOccurrences(of: "min/km", with: "", options: .caseInsensitive)
        cleaned = cleaned.trimmingCharacters(in: .whitespaces)
        
        let components = cleaned.components(separatedBy: ":")
        guard components.count == 2 else {
            print("⚠️ Invalid pace format: \(pace) - expected M:SS format")
            return nil
        }
        
        guard let minutes = Int(components[0].trimmingCharacters(in: .whitespaces)),
              let seconds = Int(components[1].trimmingCharacters(in: .whitespaces)),
              minutes >= 0,
              seconds >= 0 && seconds < 60 else {
            print("⚠️ Invalid pace format: \(pace) - invalid minutes or seconds")
            return nil
        }
        
        return minutes * 60 + seconds
    }
}

// MARK: - Error Types

enum PolarWorkoutSyncError: Error, LocalizedError {
    case emptyPacingSegments
    case invalidPaceFormat(String)
    case invalidResponse
    case unauthorized
    case forbidden
    case apiError(message: String)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .emptyPacingSegments:
            return "No pacing segments found. Please create a race plan with pacing segments first."
        case .invalidPaceFormat(let pace):
            return "Invalid pace format: \(pace). Expected format: M:SS (e.g., 5:30)"
        case .invalidResponse:
            return "Invalid response from Polar API"
        case .unauthorized:
            return "Unauthorized. Please reconnect your Polar account."
        case .forbidden:
            return "Access forbidden. Check your Polar API permissions."
        case .apiError(let message):
            return "Polar API error: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
