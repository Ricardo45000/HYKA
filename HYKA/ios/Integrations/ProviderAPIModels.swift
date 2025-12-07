import Foundation

// MARK: - Common Models

/// Unified workout model used by the app to display activities from any provider
struct ProviderWorkout {
    let providerActivityId: String
    let name: String?
    let startTime: Date
    let elapsedSeconds: Int
    let movingSeconds: Int?
    let distanceMeters: Double
    let elevationGainMeters: Double
    let avgHR: Int?
    let maxHR: Int?
    let avgPaceSPerKm: Int?
    let activityTypeCode: ActivityTypeCode
    let timezoneOffsetMinutes: Int?
}

/// Unified sample/stream data point (heart rate, gps, etc.)
/// Property names match database schema
struct ProviderSample {
    let tS: Int // Time offset in seconds from start
    let lat: Double?
    let lon: Double?
    let altM: Double?
    let hr: Int?
    let cadence: Int?
    let paceSPerKm: Int?
    let airTemperatureC: Double?
    let speedMPerS: Double?
    let stepsPerMinute: Int?
    let power: Int?
}

/// Unified lap data
/// Property names match database schema
struct ProviderLap {
    let index: Int
    let startOffsetS: Int // Seconds from workout start
    let durationS: Int
    let distanceM: Double
    let elevationGainM: Double?
    let avgHR: Int?
    let maxHR: Int?
    let avgPaceSPerKm: Int?
}

// MARK: - Helpers

private func parseISO8601(_ dateString: String?) -> Date? {
    guard let dateString = dateString else { return nil }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.date(from: dateString) ?? ISO8601DateFormatter().date(from: dateString)
}

// MARK: - Strava API Models

struct StravaActivity: Codable {
    let id: Int
    let name: String?
    let distance: Double? // meters
    let movingTime: Int? // seconds
    let elapsedTime: Int? // seconds
    let totalElevationGain: Double? // meters
    let type: String?
    let sportType: String?
    let startDate: String? // ISO 8601
    let startDateLocal: String? // ISO 8601
    let timezone: String?
    let utcOffset: Double?
    let averageSpeed: Double? // meters/second
    let maxSpeed: Double? // meters/second
    let averageHeartrate: Double?
    let maxHeartrate: Double?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case distance
        case movingTime = "moving_time"
        case elapsedTime = "elapsed_time"
        case totalElevationGain = "total_elevation_gain"
        case type
        case sportType = "sport_type"
        case startDate = "start_date"
        case startDateLocal = "start_date_local"
        case timezone
        case utcOffset = "utc_offset"
        case averageSpeed = "average_speed"
        case maxSpeed = "max_speed"
        case averageHeartrate = "average_heartrate"
        case maxHeartrate = "max_heartrate"
    }
    
    func toProviderWorkout() -> ProviderWorkout {
        let startTime = parseISO8601(startDate) ?? Date()
        let offsetMinutes = utcOffset.map { Int($0 / 60) }
        
        let elapsedSeconds = elapsedTime ?? 0
        let distanceMeters = distance ?? 0
        
        // Calculate pace from average speed (m/s -> s/km)
        let avgPaceSPerKm: Int? = averageSpeed.flatMap { speed in
            speed > 0 ? Int(1000 / speed) : nil
        }
        
        return ProviderWorkout(
            providerActivityId: String(id),
            name: name,
            startTime: startTime,
            elapsedSeconds: elapsedSeconds,
            movingSeconds: movingTime,
            distanceMeters: distanceMeters,
            elevationGainMeters: totalElevationGain ?? 0,
            avgHR: averageHeartrate.map(Int.init),
            maxHR: maxHeartrate.map(Int.init),
            avgPaceSPerKm: avgPaceSPerKm,
            activityTypeCode: ActivityTypeMapper.code(for: sportType ?? type),
            timezoneOffsetMinutes: offsetMinutes
        )
    }
}

// MARK: - Suunto API Models

struct SuuntoActivity: Codable {
    let id: String
    let name: String?
    let startTime: Date?
    let duration: Int? // Duration in seconds
    let distance: Double? // Distance in meters
    let sport: String? // Sport type (e.g., "Running", "Cycling")
    
    // Additional fields from Suunto API (adjust based on actual API response)
    let elevationGain: Double?
    let averageHeartRate: Int?
    let maxHeartRate: Int?
    let calories: Int?
    let deviceName: String?
    
    func toProviderWorkout() -> ProviderWorkout? {
        guard let startTime = startTime,
              let elapsedSeconds = duration,
              let distanceMeters = distance else {
            return nil
        }
        
        let activityTypeCode = ActivityTypeMapper.code(for: sport)
        let elevationGainMeters = elevationGain ?? 0.0
        
        // Calculate average pace in seconds per km
        let avgPaceSPerKm: Int?
        if distanceMeters > 0 && elapsedSeconds > 0 {
            avgPaceSPerKm = Int(round(Double(elapsedSeconds) / (distanceMeters / 1000.0)))
        } else {
            avgPaceSPerKm = nil
        }
        
        return ProviderWorkout(
            providerActivityId: id,
            name: name,
            startTime: startTime,
            elapsedSeconds: elapsedSeconds,
            movingSeconds: elapsedSeconds, // Suunto API might not distinguish moving time
            distanceMeters: distanceMeters,
            elevationGainMeters: elevationGainMeters,
            avgHR: averageHeartRate,
            maxHR: maxHeartRate,
            avgPaceSPerKm: avgPaceSPerKm,
            activityTypeCode: activityTypeCode,
            timezoneOffsetMinutes: nil // Suunto API might provide this
        )
    }
}

// MARK: - Polar API Models

struct PolarActivity: Codable {
    let id: Int
    let uploadTime: String? // ISO 8601
    let startTime: String? // ISO 8601
    let duration: String? // ISO 8601 duration (e.g., PT1H30M)
    let distance: Double? // meters
    let calories: Int?
    let heartRate: PolarHeartRateSummary?
    let sport: String?
    let hasGps: Bool?
    
    struct PolarHeartRateSummary: Codable {
        let average: Int?
        let maximum: Int?
    }
    
    // Helper to parse ISO 8601 Duration (PT1H30M) to seconds
    // Simplified implementation
    func parseDuration(_ durationString: String?) -> Int? {
        // TODO: Implement proper ISO duration parsing
        return 3600 // Placeholder
    }
    
    var activityId: String? {
        return String(id)
    }
    
    func toProviderWorkout() -> ProviderWorkout? {
        guard let startTimeString = startTime,
              let startTime = parseISO8601(startTimeString) else {
            return nil
        }
        
        let elapsedSeconds = parseDuration(duration) ?? 0
        let distanceMeters = distance ?? 0
        
        return ProviderWorkout(
            providerActivityId: String(id),
            name: "Polar Workout", // Polar API might not provide user-defined name in summary
            startTime: startTime,
            elapsedSeconds: elapsedSeconds,
            movingSeconds: elapsedSeconds,
            distanceMeters: distanceMeters,
            elevationGainMeters: 0, // Summary might not have elevation
            avgHR: heartRate?.average,
            maxHR: heartRate?.maximum,
            avgPaceSPerKm: nil, // Calc later
            activityTypeCode: ActivityTypeMapper.code(for: sport),
            timezoneOffsetMinutes: nil
        )
    }
}

// MARK: - Coros API Models (Placeholder)

struct CorosActivity: Codable {
    let id: String
    // Add fields when API is known
}
