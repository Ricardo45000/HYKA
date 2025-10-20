import Foundation

// MARK: - Common API Models

/// Unified workout data structure for all providers
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

/// Unified sample data structure
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
}

// MARK: - Helpers

private let isoDateTimeFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
}()

private func parseISO8601(_ string: String?) -> Date? {
    guard let string else { return nil }
    return isoDateTimeFormatter.date(from: string) ?? ISO8601DateFormatter().date(from: string)
}

/// Unified lap data structure
struct ProviderLap {
    let index: Int
    let startOffsetS: Int
    let durationS: Int
    let distanceM: Double
    let elevationGainM: Double
    let avgHR: Int?
    let avgPaceSPerKm: Int?
}

// MARK: - Garmin API Models

struct GarminActivity: Codable {
    let activityId: String
    let activityName: String?
    let startTimeGMT: String? // ISO 8601 format
    let startTimeLocal: String? // ISO 8601 format
    let duration: Double? // seconds
    let distance: Double? // meters
    let elevationGain: Double? // meters
    let elevationLoss: Double? // meters
    let averageHR: Int?
    let maxHR: Int?
    let averageSpeed: Double? // meters per second
    let maxSpeed: Double? // meters per second
    let activityType: GarminActivityType?
    
    enum CodingKeys: String, CodingKey {
        case activityId
        case activityName
        case startTimeGMT
        case startTimeLocal
        case duration
        case distance
        case elevationGain
        case elevationLoss
        case averageHR
        case maxHR
        case averageSpeed
        case maxSpeed
        case activityType
    }
    
    func toProviderWorkout() -> ProviderWorkout {
        let startTime = startTimeGMT.flatMap { parseISO8601($0) } ??
                        startTimeLocal.flatMap { parseISO8601($0) } ??
                        Date()
        let localStart = startTimeLocal.flatMap { parseISO8601($0) }
        let offsetMinutes: Int?
        if let localStart, let gmtStart = startTimeGMT.flatMap({ parseISO8601($0) }) {
            let delta = localStart.timeIntervalSince1970 - gmtStart.timeIntervalSince1970
            offsetMinutes = Int(delta / 60)
        } else {
            offsetMinutes = nil
        }
        
        let elapsedSeconds = Int(duration ?? 0)
        let distanceMeters = distance ?? 0
        let elevationGainMeters = elevationGain ?? 0
        
        // Calculate pace from average speed (meters per second to seconds per km)
        let avgPaceSPerKm: Int? = averageSpeed.map { speed in
            speed > 0 ? Int(1000 / speed) : nil
        } ?? nil
        
        return ProviderWorkout(
            providerActivityId: activityId,
            name: activityName,
            startTime: startTime,
            elapsedSeconds: elapsedSeconds,
            movingSeconds: elapsedSeconds, // Garmin doesn't always provide moving time separately
            distanceMeters: distanceMeters,
            elevationGainMeters: elevationGainMeters,
            avgHR: averageHR,
            maxHR: maxHR,
            avgPaceSPerKm: avgPaceSPerKm,
            activityTypeCode: ActivityTypeMapper.code(for: activityType?.typeKey),
            timezoneOffsetMinutes: offsetMinutes
        )
    }
}

struct GarminActivityType: Codable {
    let typeId: Int
    let typeKey: String
    let parentTypeId: Int?
    let sortOrder: Int?
}

extension GarminActivity {
    /// Build a GarminActivity from Garmin Connect API JSON payload
    /// This handles the response format from connect.garmin.com endpoints
    static func fromConnectJSON(_ json: [String: Any]) -> GarminActivity? {
        // Garmin Connect API uses these field names - activityId can be Int or String
        let activityId: Int
        if let id = json["activityId"] as? Int {
            activityId = id
        } else if let idString = json["activityId"] as? String, let id = Int(idString) {
            activityId = id
        } else {
            return nil
        }
        
        let activityName = json["activityName"] as? String
        let startTimeGMT = json["startTimeGMT"] as? String ?? json["startTimeGmt"] as? String
        let startTimeLocal = json["startTimeLocal"] as? String
        let duration = json["duration"] as? Double ?? (json["movingDuration"] as? Double)
        let distance = json["distance"] as? Double ?? (json["distance"] as? Int).map(Double.init)
        let elevationGain = json["elevationGain"] as? Double ?? (json["elevationGain"] as? Int).map(Double.init)
        let elevationLoss = json["elevationLoss"] as? Double ?? (json["elevationLoss"] as? Int).map(Double.init)
        let averageHR = json["averageHR"] as? Int ?? json["averageHeartRate"] as? Int
        let maxHR = json["maxHR"] as? Int ?? json["maxHeartRate"] as? Int
        let averageSpeed = json["averageSpeed"] as? Double
        let maxSpeed = json["maxSpeed" ] as? Double
        
        var activityType: GarminActivityType? = nil
        if let typeId = json["activityTypeId"] as? Int {
            let typeKey = json["activityType"] as? String ?? 
                         (json["activityType"] as? [String: Any])?["typeKey"] as? String ??
                         "unknown"
            activityType = GarminActivityType(
                typeId: typeId,
                typeKey: typeKey,
                parentTypeId: json["parentTypeId"] as? Int,
                sortOrder: nil
            )
        }
        
        return GarminActivity(
            activityId: String(activityId),
            activityName: activityName,
            startTimeGMT: startTimeGMT,
            startTimeLocal: startTimeLocal,
            duration: duration,
            distance: distance,
            elevationGain: elevationGain,
            elevationLoss: elevationLoss,
            averageHR: averageHR,
            maxHR: maxHR,
            averageSpeed: averageSpeed,
            maxSpeed: maxSpeed,
            activityType: activityType
        )
    }
    
    /// Build a GarminActivity from Wellness API JSON payload
    /// Reference: Wellness API documentation - /rest/activities endpoint
    static func fromWellnessJSON(_ json: [String: Any]) -> GarminActivity? {
        // Identify activity ID (Wellness API uses activityId as number)
        let activityId: String
        if let id = json["activityId"] as? Int {
            activityId = String(id)
        } else if let id = json["activityId"] as? String {
            activityId = id
        } else if let summaryId = json["summaryId"] as? String {
            activityId = summaryId
        } else {
            // Log missing ID for debugging
            print("⚠️ Wellness JSON missing activity ID. Available keys: \(Array(json.keys).joined(separator: ", "))")
            return nil
        }
        
        let activityName = json["activityName"] as? String
        
        // Wellness API uses startTimeInSeconds (integer int32, Unix Epoch Timestamp) and startTimeOffsetInSeconds
        let startTimeGMT: String?
        if let startTimeSeconds = json["startTimeInSeconds"] as? Int {
            let date = Date(timeIntervalSince1970: TimeInterval(startTimeSeconds))
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            startTimeGMT = formatter.string(from: date)
        } else if let startTimeSeconds = json["startTimeInSeconds"] as? Double {
            let date = Date(timeIntervalSince1970: startTimeSeconds)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            startTimeGMT = formatter.string(from: date)
        } else {
            startTimeGMT = json["startTimeGMT"] as? String ??
                          json["startTimeGmt"] as? String ??
                          json["startTimeUTC"] as? String ??
                          json["startTimeUtc"] as? String ??
                          json["startTime"] as? String
        }
        
        // Wellness API may provide startTimeLocal, or we can calculate it from startTimeInSeconds + startTimeOffsetInSeconds
        let startTimeLocal: String?
        if let local = json["startTimeLocal"] as? String {
            startTimeLocal = local
        } else if let startTimeSeconds = json["startTimeInSeconds"] as? Int,
                  let offsetSeconds = json["startTimeOffsetInSeconds"] as? Int {
            // Calculate local time from UTC + offset
            let localTimeSeconds = startTimeSeconds + offsetSeconds
            let date = Date(timeIntervalSince1970: TimeInterval(localTimeSeconds))
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            startTimeLocal = formatter.string(from: date)
        } else {
            startTimeLocal = nil
        }
        
        // Wellness API uses durationInSeconds
        let duration: Double?
        if let durationSeconds = json["durationInSeconds"] as? Int {
            duration = Double(durationSeconds)
        } else if let durationSeconds = json["durationInSeconds"] as? Double {
            duration = durationSeconds
        } else {
            duration = json["duration"] as? Double ??
                      (json["elapsedTimeInSeconds"] as? Double)
        }
        
        // Wellness API uses distanceInMeters (number/float)
        let distance: Double?
        if let distanceMeters = json["distanceInMeters"] as? Double {
            distance = distanceMeters
        } else if let distanceMeters = json["distanceInMeters"] as? Int {
            distance = Double(distanceMeters)
        } else {
            distance = json["distance"] as? Double
        }
        
        // Wellness API uses totalElevationGainInMeters and totalElevationLossInMeters (number/float)
        let elevationGain: Double?
        if let gain = json["totalElevationGainInMeters"] as? Double {
            elevationGain = gain
        } else if let gain = json["totalElevationGainInMeters"] as? Int {
            elevationGain = Double(gain)
        } else {
            elevationGain = json["elevationGain"] as? Double ??
                           json["elevationGainInMeters"] as? Double ??
                           json["totalAscent"] as? Double
        }
        
        let elevationLoss: Double?
        if let loss = json["totalElevationLossInMeters"] as? Double {
            elevationLoss = loss
        } else if let loss = json["totalElevationLossInMeters"] as? Int {
            elevationLoss = Double(loss)
        } else {
            elevationLoss = json["elevationLoss"] as? Double ??
                           json["elevationLossInMeters"] as? Double ??
                           json["totalDescent"] as? Double
        }
        
        // Wellness API heart rate fields
        let averageHR: Int?
        if let hr = json["averageHeartRateInBeatsPerMinute"] as? Int {
            averageHR = hr
        } else if let hr = json["averageHeartRateInBeatsPerMinute"] as? Double {
            averageHR = Int(hr)
        } else {
            averageHR = json["averageHR"] as? Int ??
                       json["averageHeartRate"] as? Int
        }
        
        let maxHR: Int?
        if let hr = json["maximumHeartRateInBeatsPerMinute"] as? Int {
            maxHR = hr
        } else if let hr = json["maximumHeartRateInBeatsPerMinute"] as? Double {
            maxHR = Int(hr)
        } else {
            maxHR = json["maxHR"] as? Int ??
                   json["maximumHeartRate"] as? Int
        }
        
        // Wellness API uses averageSpeedInMetersPerSecond and maxSpeedInMetersPerSecond (number/float)
        let averageSpeed: Double?
        if let speed = json["averageSpeedInMetersPerSecond"] as? Double {
            averageSpeed = speed
        } else if let speed = json["averageSpeedInMetersPerSecond"] as? Int {
            averageSpeed = Double(speed)
        } else if let speed = json["averageSpeed"] as? Double {
            averageSpeed = speed
        } else if let paceMin = json["averagePaceInMinutesPerKilometer"] as? Double, paceMin > 0 {
            // Convert pace (minutes per km) to speed (m/s)
            // paceMin = minutes/km, so speed = 1000m / (paceMin * 60s) = 1000 / (paceMin * 60) m/s
            averageSpeed = 1000.0 / (paceMin * 60.0)
        } else if let paceMs = json["averagePaceInMillisecondsPerKilometer"] as? Double, paceMs > 0 {
            // Convert pace (ms per km) to speed (m/s)
            averageSpeed = 1000.0 / (paceMs / 1000.0)
        } else {
            averageSpeed = nil
        }
        
        let maxSpeed: Double?
        if let speed = json["maxSpeedInMetersPerSecond"] as? Double {
            maxSpeed = speed
        } else if let speed = json["maxSpeedInMetersPerSecond"] as? Int {
            maxSpeed = Double(speed)
        } else {
            maxSpeed = json["maxSpeed"] as? Double ??
                      json["maximumSpeed"] as? Double
        }
        
        // Wellness API uses activityType as a string (e.g., "RUNNING")
        var activityType: GarminActivityType? = nil
        if let typeString = json["activityType"] as? String {
            // Wellness API returns activityType as string like "RUNNING"
            // Map it to a GarminActivityType
            let typeKey = typeString.lowercased()
            activityType = GarminActivityType(
                typeId: 0, // Wellness API doesn't provide typeId
                typeKey: typeKey,
                parentTypeId: nil,
                sortOrder: nil
            )
        } else if let typeId = json["activityTypeId"] as? Int {
            let typeKey = json["activityTypeKey"] as? String ??
                          json["activityTypeName"] as? String ??
                          "unknown"
            let parentTypeId = json["activityParentTypeId"] as? Int
            activityType = GarminActivityType(
                typeId: typeId,
                typeKey: typeKey,
                parentTypeId: parentTypeId,
                sortOrder: nil
            )
        } else if let typeDict = json["activityType"] as? [String: Any],
                  let typeId = typeDict["typeId"] as? Int {
            let typeKey = typeDict["typeKey"] as? String ?? "unknown"
            let parentTypeId = typeDict["parentTypeId"] as? Int
            let sortOrder = typeDict["sortOrder"] as? Int
            activityType = GarminActivityType(
                typeId: typeId,
                typeKey: typeKey,
                parentTypeId: parentTypeId,
                sortOrder: sortOrder
            )
        }
        
        return GarminActivity(
            activityId: activityId,
            activityName: activityName,
            startTimeGMT: startTimeGMT,
            startTimeLocal: startTimeLocal,
            duration: duration,
            distance: distance,
            elevationGain: elevationGain,
            elevationLoss: elevationLoss,
            averageHR: averageHR,
            maxHR: maxHR,
            averageSpeed: averageSpeed,
            maxSpeed: maxSpeed,
            activityType: activityType
        )
    }
}

// MARK: - Coros API Models (placeholder - structure for future implementation)

struct CorosActivity: Codable {
    // Coros API structure
    // This will need to be implemented based on Coros's actual API
    let activityId: String?
    
    func toProviderWorkout() -> ProviderWorkout? {
        // Implementation needed when Coros API is integrated
        return nil
    }
}

// MARK: - Suunto API Models (placeholder - structure for future implementation)

struct SuuntoActivity: Codable {
    // Suunto API structure
    // Suunto uses Movescount API or newer Suunto Plus API
    // This will need to be implemented based on Suunto's actual API
    let activityId: String?
    
    func toProviderWorkout() -> ProviderWorkout? {
        // Implementation needed when Suunto API is integrated
        return nil
    }
}

// MARK: - Polar API Models

struct PolarActivity: Codable {
    let id: String? // exerciseId
    let uploadTime: String?
    let polarUser: String?
    let device: String?
    let deviceId: String?
    let startTime: String?
    let startTimeUtcOffset: Int?
    let duration: String? // ISO 8601 duration format (PT1H30M45S)
    let calories: Int?
    let distance: Double? // meters
    let heartRate: PolarHeartRate?
    let trainingLoad: PolarTrainingLoad?
    let sport: String?
    let hasRoute: Bool?
    let clubId: Int?
    let clubName: String?
    let notes: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case uploadTime = "upload_time"
        case polarUser = "polar_user"
        case device
        case deviceId = "device_id"
        case startTime = "start_time"
        case startTimeUtcOffset = "start_time_utc_offset"
        case duration
        case calories
        case distance
        case heartRate = "heart_rate"
        case trainingLoad = "training_load"
        case sport
        case hasRoute = "has_route"
        case clubId = "club_id"
        case clubName = "club_name"
        case notes
    }
    
    var activityId: String? {
        return id
    }
    
    /// Convert Polar exercise to ProviderWorkout
    func toProviderWorkout() -> ProviderWorkout? {
        guard let id = id,
              let startTimeStr = startTime,
              let startTime = parseISO8601(startTimeStr) else {
            return nil
        }
        
        // Parse duration from ISO 8601 format (PT1H30M45S)
        let elapsedSeconds = parseDuration(duration ?? "PT0S")
        
        // Parse distance (convert from meters if needed)
        let distanceMeters = distance ?? 0.0
        
        // Parse elevation gain (not directly available in exercise summary, would need detailed exercise)
        let elevationGainMeters = 0.0
        
        // Get heart rate data
        let avgHR = heartRate?.avg
        let maxHR = heartRate?.max
        
        // Calculate average pace if we have distance and duration
        let avgPaceSPerKm: Int? = {
            guard distanceMeters > 0, elapsedSeconds > 0 else { return nil }
            let distanceKm = distanceMeters / 1000.0
            let paceSecondsPerKm = Double(elapsedSeconds) / distanceKm
            return Int(paceSecondsPerKm)
        }()
        
        // Map Polar sport to ActivityTypeCode
        let activityType = mapPolarSportToActivityType(sport)
        
        // Calculate timezone offset (Polar provides offset in minutes)
        let timezoneOffsetMinutes = startTimeUtcOffset
        
        // Create workout name from sport and date
        let workoutName = sport ?? "Exercise"
        
        return ProviderWorkout(
            providerActivityId: id,
            name: workoutName,
            startTime: startTime,
            elapsedSeconds: elapsedSeconds,
            movingSeconds: nil, // Not available in exercise summary
            distanceMeters: distanceMeters,
            elevationGainMeters: elevationGainMeters,
            avgHR: avgHR,
            maxHR: maxHR,
            avgPaceSPerKm: avgPaceSPerKm,
            activityTypeCode: activityType,
            timezoneOffsetMinutes: timezoneOffsetMinutes
        )
    }
    
    /// Parse ISO 8601 duration string (PT1H30M45S) to seconds
    private func parseDuration(_ durationStr: String) -> Int {
        // Remove PT prefix
        var remaining = durationStr.replacingOccurrences(of: "PT", with: "")
        var totalSeconds = 0
        
        // Parse hours
        if let hourRange = remaining.range(of: "H") {
            if let hours = Int(remaining[..<hourRange.lowerBound]) {
                totalSeconds += hours * 3600
            }
            remaining = String(remaining[hourRange.upperBound...])
        }
        
        // Parse minutes
        if let minuteRange = remaining.range(of: "M") {
            if let minutes = Int(remaining[..<minuteRange.lowerBound]) {
                totalSeconds += minutes * 60
            }
            remaining = String(remaining[minuteRange.upperBound...])
        }
        
        // Parse seconds
        if let secondRange = remaining.range(of: "S") {
            if let seconds = Int(remaining[..<secondRange.lowerBound]) {
                totalSeconds += seconds
            }
        }
        
        return totalSeconds
    }
    
    /// Map Polar sport name to ActivityTypeCode
    private func mapPolarSportToActivityType(_ sport: String?) -> ActivityTypeCode {
        guard let sport = sport?.lowercased() else {
            return .other
        }
        
        // Map based on Polar's sport names from documentation
        switch sport {
        case "running", "run":
            return .run
        case "trail running", "trail run", "trailrun":
            return .trailRun
        case "cycling", "bike", "biking", "road cycling", "mountain biking":
            return .bike
        case "swimming", "swim", "open water swimming":
            return .swim
        case "hiking", "hike":
            return .hike
        case "walking", "walk":
            return .walk
        case "rowing", "row":
            return .row
        case "strength training", "strength", "functional strength training":
            return .strength
        case "yoga":
            return .yoga
        default:
            // Use ActivityTypeMapper for other cases
            return ActivityTypeMapper.code(for: sport)
        }
    }
}

struct PolarHeartRate: Codable {
    let avg: Int?
    let max: Int?
    
    enum CodingKeys: String, CodingKey {
        case avg
        case max
    }
}

struct PolarTrainingLoad: Codable {
    let value: Double?
    
    enum CodingKeys: String, CodingKey {
        case value
    }
}

