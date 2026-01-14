import Foundation

/// Service for syncing race plans to Garmin Connect as structured workouts
/// Converts pacing segments and fueling stations into Garmin workout format
@MainActor
final class GarminWorkoutSyncService {
    private let userId: UUID
    private let supabaseAnonKey: String
    private let edgeFunctionURL: String
    
    init(userId: UUID) {
        self.userId = userId
        // Get Supabase config - these should be available via Config
        self.supabaseAnonKey = Config.supabaseAnonKey
        self.edgeFunctionURL = "\(Config.edgeFunctionsBaseURL)/garmin-workout-create"
    }
    
    // MARK: - Main Sync Function
    
    /// Sync a race plan to Garmin Connect as a structured workout
    /// - Parameters:
    ///   - workoutName: Name of the workout (race strategy name)
    ///   - pacingSegments: Array of pacing segments from race calendar
    ///   - fuelingStations: Array of fueling stations (aligned with pacing segments by index)
    ///   - raceDate: Optional race date for scheduling
    /// - Returns: Workout ID from Garmin Connect
    func syncRacePlanToGarmin(
        workoutName: String,
        pacingSegments: [PacingSegment],
        fuelingStations: [FuelingStation],
        raceDate: Date?
    ) async throws -> String {
        print("🔄 Starting Garmin workout sync...")
        print("📋 Workout Name: \(workoutName)")
        print("📋 Pacing Segments: \(pacingSegments.count)")
        print("📋 Fueling Stations: \(fuelingStations.count)")
        
        // Validate inputs
        guard !pacingSegments.isEmpty else {
            throw GarminWorkoutSyncError.emptyPacingSegments
        }
        
        // Convert race plan to Garmin workout format
        let workoutJSON = try convertToGarminWorkout(
            workoutName: workoutName,
            pacingSegments: pacingSegments,
            fuelingStations: fuelingStations,
            raceDate: raceDate
        )
        
        // Create workout in Garmin Connect
        let workoutId = try await createWorkoutInGarmin(
            workoutJSON: workoutJSON
        )
        
        print("✅ Workout created successfully with ID: \(workoutId)")
        return workoutId
    }
    
    /// Schedule a workout in Garmin Connect for a specific date
    /// - Parameters:
    ///   - workoutId: The workout ID from Garmin Connect
    ///   - date: The date to schedule the workout
    func scheduleWorkout(workoutId: String, date: Date) async throws {
        print("📅 Scheduling workout \(workoutId) for date: \(date)")
        
        // Extract calendar date components using local calendar to get the user's intended calendar date
        // This ensures that if a date represents "March 20" in the user's timezone, we get March 20
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        
        guard let year = components.year,
              let month = components.month,
              let day = components.day else {
            throw GarminWorkoutSyncError.invalidDate
        }
        
        // Format as YYYY-mm-dd for Garmin API (required format per Training API V2)
        let dateString = String(format: "%04d-%02d-%02d", year, month, day)
        
        // Validate format matches API requirement (YYYY-mm-dd)
        print("   📅 Formatted date string: \(dateString) (year: \(year), month: \(month), day: \(day))")
        
        // Call Edge Function to schedule the workout
        let url = URL(string: "\(Config.edgeFunctionsBaseURL)/garmin-workout-schedule")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        
        let requestBody: [String: Any] = [
            "user_id": userId.uuidString,
            "workout_id": workoutId,
            "date": dateString
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody, options: [])
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GarminWorkoutSyncError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Workout scheduling failed: \(errorString)")
            
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = errorJson["error"] as? String {
                throw GarminWorkoutSyncError.apiError(message: errorMessage)
            } else {
                throw GarminWorkoutSyncError.apiError(message: "HTTP \(httpResponse.statusCode): \(errorString)")
            }
        }
        
        print("✅ Workout scheduled successfully")
    }
    
    // MARK: - Edge Function Integration
    
    /// Create workout in Garmin Connect via Edge Function (handles token refresh automatically)
    private func createWorkoutInGarmin(
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
            throw GarminWorkoutSyncError.invalidResponse
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
                    throw GarminWorkoutSyncError.unauthorized
                } else if httpResponse.statusCode == 403 {
                    throw GarminWorkoutSyncError.forbidden
                } else {
                    throw GarminWorkoutSyncError.apiError(message: errorMessage)
                }
            } else {
                throw GarminWorkoutSyncError.apiError(message: "HTTP \(httpResponse.statusCode): \(errorString)")
            }
        }
        
        // Parse response to get workout ID
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw GarminWorkoutSyncError.invalidResponse
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
    
    /// Convert race plan data to Garmin workout JSON format
    private func convertToGarminWorkout(
        workoutName: String,
        pacingSegments: [PacingSegment],
        fuelingStations: [FuelingStation],
        raceDate: Date?
    ) throws -> [String: Any] {
        var workoutSteps: [[String: Any]] = []
        
        // Process each pacing segment and its corresponding fueling station
        var stepOrder = 1 // Garmin API uses 1-based step ordering
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
        
        // Calculate estimated total duration from all distance segments
        var totalEstimatedSeconds: Double = 0
        for segment in pacingSegments {
            let distanceKm = max(segment.segmentDistance, 0.1)
            if let paceSecondsPerKm = parsePaceString(segment.estimatedPace) {
                let segmentTimeSeconds = Double(paceSecondsPerKm) * distanceKm
                totalEstimatedSeconds += segmentTimeSeconds
            }
        }
        // Add time for fueling stations (30 seconds each - now using TIME duration instead of OPEN)
        let fuelingTimeSeconds = Double(fuelingStations.count) * 30.0
        totalEstimatedSeconds += fuelingTimeSeconds
        
        // Convert to hours, minutes, seconds for display
        let totalHours = Int(totalEstimatedSeconds) / 3600
        let totalMinutes = (Int(totalEstimatedSeconds) % 3600) / 60
        let totalSeconds = Int(totalEstimatedSeconds) % 60
        
        // Format duration string
        var durationString = ""
        if totalHours > 0 {
            durationString = "\(totalHours)h \(totalMinutes)m"
        } else if totalMinutes > 0 {
            durationString = "\(totalMinutes)m \(totalSeconds)s"
        } else {
            durationString = "\(totalSeconds)s"
        }
        
        // Build workout JSON structure according to Garmin Training API V2
        // Reference: Garmin Connect Developer Program Training API V2
        // Workouts must have segments, and steps are inside segments
        // For single-sport workouts, we need one segment containing all steps
        let segment: [String: Any] = [
            "segmentOrder": 1,
            "sport": "RUNNING",
            "steps": workoutSteps
        ]
        
        // Build description with estimated duration
        let description = "Race strategy synced from HYKA\nEstimated duration: \(durationString)"
        
        let workout: [String: Any] = [
            "workoutName": workoutName.isEmpty ? "Race Workout" : workoutName,
            "description": description,
            "sport": "RUNNING", // Sport type must be uppercase
            "segments": [segment] // Segments array is required - cannot be null or empty
        ]
        
        // Note: Garmin may calculate duration from steps, but we include it in description
        // for visibility. The actual duration calculation happens on the device during the workout.
        
        return workout
    }
    
    /// Create a run step from a pacing segment
    /// Format according to Garmin Training API V2 WorkoutStep structure
    private func createRunStep(from segment: PacingSegment) throws -> [String: Any] {
        // Validate segment distance
        let distanceKm = max(segment.segmentDistance, 0.1) // Minimum 0.1 km
        
        // Parse pace (in min/km format, e.g., "5:57 m/km")
        guard let paceSecondsPerKm = parsePaceString(segment.estimatedPace) else {
            throw GarminWorkoutSyncError.invalidPaceFormat(segment.estimatedPace)
        }
        
        // Calculate pace range (±5 seconds per km)
        let paceMinSecondsPerKm = max(paceSecondsPerKm - 5, 1)
        let paceMaxSecondsPerKm = paceSecondsPerKm + 5
        
        // Convert pace from seconds per km to seconds per mile
        // 1 mile = 1.609344 km, so time per mile = time per km * 1.609344
        let paceMinSecondsPerMile = Double(paceMinSecondsPerKm) * 1.609344
        let paceMaxSecondsPerMile = Double(paceMaxSecondsPerKm) * 1.609344
        
        // Convert to m/s for Garmin API (API expects pace in m/s format)
        // Speed (m/s) = distance (meters) / time (seconds)
        // 1 mile = 1609.344 meters
        let metersPerMile = 1609.344
        let paceMinMetersPerSecond = metersPerMile / paceMinSecondsPerMile
        let paceMaxMetersPerSecond = metersPerMile / paceMaxSecondsPerMile
        
        print("📊 Pace conversion: \(segment.estimatedPace) -> \(paceSecondsPerKm)s/km -> \(String(format: "%.1f", paceMinSecondsPerMile))s/mi -> \(String(format: "%.3f", paceMinMetersPerSecond)) m/s")
        
        // Build step according to Garmin Training API V2 format
        var step: [String: Any] = [
            "type": "WorkoutStep",
            "stepOrder": 0, // Will be set by caller based on index
            "intensity": "ACTIVE",
            "description": "Segment: \(segment.from) → \(segment.to)",
            "durationType": "DISTANCE",
            "durationValue": Double(distanceKm),
            "durationValueType": "KILOMETER",
            "targetType": "PACE",
            "targetValueLow": paceMinMetersPerSecond,
            "targetValueHigh": paceMaxMetersPerSecond
        ]
        
        // Add heart rate information to description for running workouts
        // Garmin API does not support secondary targets for RUNNING (only CYCLING/SWIMMING)
        if !segment.heartRate.isEmpty {
            if let currentDesc = step["description"] as? String {
                step["description"] = "\(currentDesc)\nTarget HR: \(segment.heartRate)"
            }
        }
        
        return step
    }
    
    /// Create a fueling step from a fueling station
    /// Format according to Garmin Training API V2 WorkoutStep structure
    /// Using TIME duration (30 seconds) instead of OPEN so Garmin can calculate total workout duration
    private func createFuelingStep(from station: FuelingStation) -> [String: Any] {
        let description = """
        STATION: \(station.name)
        DRINK: \(station.water)ml
        CARBS: \(station.carbs)g
        SODIUM: \(station.sodium)mg
        """
        
        return [
            "type": "WorkoutStep",
            "stepOrder": 0, // Will be set by caller
            "intensity": "REST",
            "description": description,
            "durationType": "TIME",
            "durationValue": 30, // 30 seconds for aid station stop
            "targetType": "OPEN"
        ]
    }
    
    // MARK: - Parsing Utilities
    
    /// Parse pace string to seconds per km
    /// - Parameter pace: Pace string like "5:30", "5:57 m/km", "05:30 m/km" (minutes:seconds per km)
    /// - Returns: Total seconds per km (e.g., 330 for "5:30", 357 for "5:57 m/km")
    func parsePaceString(_ pace: String) -> Int? {
        // Remove whitespace and convert to lowercase
        var cleaned = pace.trimmingCharacters(in: .whitespaces).lowercased()
        
        // Remove common suffixes: " m/km", " m/min", "/km", etc.
        cleaned = cleaned.replacingOccurrences(of: " m/km", with: "", options: .caseInsensitive)
        cleaned = cleaned.replacingOccurrences(of: " m/min", with: "", options: .caseInsensitive)
        cleaned = cleaned.replacingOccurrences(of: "/km", with: "", options: .caseInsensitive)
        cleaned = cleaned.replacingOccurrences(of: "min/km", with: "", options: .caseInsensitive)
        cleaned = cleaned.trimmingCharacters(in: .whitespaces)
        
        // Handle formats like "5:30", "05:30", "12:45", "5:57"
        let components = cleaned.components(separatedBy: ":")
        guard components.count == 2 else {
            print("⚠️ Invalid pace format: \(pace) - expected M:SS format")
            return nil
        }
        
        // Parse minutes and seconds
        guard let minutes = Int(components[0].trimmingCharacters(in: .whitespaces)),
              let seconds = Int(components[1].trimmingCharacters(in: .whitespaces)),
              minutes >= 0,
              seconds >= 0 && seconds < 60 else {
            print("⚠️ Invalid pace format: \(pace) - invalid minutes or seconds")
            return nil
        }
        
        let totalSeconds = minutes * 60 + seconds
        return totalSeconds
    }
    
    /// Parse heart rate string to extract BPM range
    /// - Parameter hr: Heart rate string like "145 bpm", "145-155 bpm", "145 bpm avg"
    /// - Returns: Tuple of (min, max) BPM, or nil if cannot parse
    func parseHeartRateString(_ hr: String) -> (min: Int, max: Int)? {
        // Remove whitespace and convert to lowercase
        let cleaned = hr.trimmingCharacters(in: .whitespaces).lowercased()
        
        // Extract all numbers from the string
        let numbers = cleaned.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .compactMap { Int($0) }
            .filter { $0 > 0 && $0 < 300 } // Valid HR range
        
        guard !numbers.isEmpty else {
        return nil
    }
    
        if numbers.count == 1 {
            // Single value: use ±5 bpm range
            let value = numbers[0]
            return (max(value - 5, 40), min(value + 5, 220)) // Clamp to valid HR range
                } else {
            // Multiple values: use min and max
            let minValue = numbers.min() ?? numbers[0]
            let maxValue = numbers.max() ?? numbers[0]
            return (minValue, maxValue)
        }
    }
}

// MARK: - Error Types

enum GarminWorkoutSyncError: Error, LocalizedError {
    case emptyPacingSegments
    case invalidPaceFormat(String)
    case invalidResponse
    case unauthorized
    case forbidden
    case apiError(message: String)
    case networkError(Error)
    case invalidDate
    
    var errorDescription: String? {
        switch self {
        case .emptyPacingSegments:
            return "No pacing segments found. Please create a race plan with pacing segments first."
        case .invalidPaceFormat(let pace):
            return "Invalid pace format: \(pace). Expected format: M:SS (e.g., 5:30)"
        case .invalidResponse:
            return "Invalid response from Garmin API"
        case .unauthorized:
            return "Unauthorized. Please reconnect your Garmin account."
        case .forbidden:
            return "Access forbidden. Check your Garmin API permissions."
        case .apiError(let message):
            return "Garmin API error: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidDate:
            return "Invalid date format. Unable to schedule workout."
        }
    }
}
