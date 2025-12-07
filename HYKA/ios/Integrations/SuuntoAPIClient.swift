import Foundation

/// Client for fetching data from Suunto API
/// Note: This is a placeholder structure - Suunto API documentation may vary
/// Implementation would require Suunto API credentials and documentation
final class SuuntoAPIClient {
    private let accessToken: String
    
    init(accessToken: String) {
        self.accessToken = accessToken
    }
    
    /// Add required headers for Suunto API requests
    /// Suunto API requires both OAuth token and subscription key
    private func addSuuntoHeaders(to request: inout URLRequest) {
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Suunto API requires subscription key in addition to OAuth token
        // According to Suunto API docs, the header name is: Ocp-Apim-Subscription-Key
        let subscriptionKey = Config.suuntoSubscriptionKey
        request.setValue(subscriptionKey, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        
        // Also set alternative headers as fallback
        request.setValue(subscriptionKey, forHTTPHeaderField: "X-Subscription-Key")
        request.setValue(subscriptionKey, forHTTPHeaderField: "Subscription-Key")
    }
    
    /// Fetch list of activities
    func fetchActivities(after: Date? = nil) async throws -> [SuuntoActivity] {
        // Suunto Plus API endpoint for workouts
        var urlComponents = URLComponents(string: "https://cloudapi.suunto.com/v2/workouts")!
        
        if let after = after {
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime]
            urlComponents.queryItems = [
                URLQueryItem(name: "after", value: dateFormatter.string(from: after))
            ]
        }
        
        guard let url = urlComponents.url else {
            throw SuuntoAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addSuuntoHeaders(to: &request)
        
        // Debug logging
        print("🔑 Suunto API Request - URL: \(url.absoluteString)")
        print("   Subscription Key: \(Config.suuntoSubscriptionKey.prefix(10))...")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SuuntoAPIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                // Check if it's a subscription key error
                let errorText = String(data: data, encoding: .utf8) ?? ""
                if errorText.contains("subscription key") {
                    throw SuuntoAPIError.apiError(message: "Missing or invalid subscription key. Check Config.suuntoSubscriptionKey")
                }
                throw SuuntoAPIError.unauthorized
            }
            throw SuuntoAPIError.httpError(statusCode: httpResponse.statusCode)
        }
        
        // Parse Suunto workouts response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let workouts = json["workouts"] as? [[String: Any]] else {
            throw SuuntoAPIError.invalidResponse
        }
        
        // Map to SuuntoActivity (adjust field names based on actual API response)
        return workouts.compactMap { workout in
            // Parse start time if available
            var startTime: Date? = nil
            if let startTimeString = workout["startTime"] as? String {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                startTime = formatter.date(from: startTimeString) ?? ISO8601DateFormatter().date(from: startTimeString)
            }
            
            return SuuntoActivity(
                id: workout["id"] as? String ?? "",
                name: workout["name"] as? String,
                startTime: startTime,
                duration: workout["duration"] as? Int,
                distance: workout["distance"] as? Double,
                sport: workout["sport"] as? String,
                elevationGain: workout["elevationGain"] as? Double ?? workout["elevation_gain"] as? Double,
                averageHeartRate: workout["averageHeartRate"] as? Int ?? workout["avg_heart_rate"] as? Int,
                maxHeartRate: workout["maxHeartRate"] as? Int ?? workout["max_heart_rate"] as? Int,
                calories: workout["calories"] as? Int,
                deviceName: workout["deviceName"] as? String ?? workout["device_name"] as? String
            )
        }
    }
    
    /// Fetch detailed activity information
    func fetchActivity(activityId: String) async throws -> SuuntoActivity {
        // TODO: Implement
        throw SuuntoAPIError.notImplemented
    }
    
    /// Fetch activity streams (GPS, HR, cadence, etc.)
    func fetchStreams(activityId: String) async throws -> [ProviderSample] {
        // TODO: Implement
        // Suunto activities are typically stored as FIT files or JSON
        // Would need to download and parse the activity data
        throw SuuntoAPIError.notImplemented
    }
    
    /// Fetch activity laps
    func fetchLaps(activityId: String) async throws -> [ProviderLap] {
        // TODO: Implement
        throw SuuntoAPIError.notImplemented
    }
    
    // MARK: - Health Metrics (247 API)
    // Reference: https://apizone.suunto.com/api-details#api=new-247-api
    // The 247 API provides: steps, energy, continuous HR, sleep, and recovery data
    
    /// Fetch daily 247 data (steps, energy, HR) for a specific date
    func fetch247DailyData(date: Date) async throws -> [String: Any]? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)
        
        // Suunto 247 API endpoint for daily data
        let url = URL(string: "https://cloudapi.suunto.com/v2/247/daily/\(dateString)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addSuuntoHeaders(to: &request)
        
        print("🔍 Fetching Suunto 247 daily data for \(dateString)")
        print("   URL: \(url.absoluteString)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SuuntoAPIError.invalidResponse
        }
        
        print("   Status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 404 {
            print("   No data for this date")
            return nil
        }
        
        if httpResponse.statusCode == 401 {
            let errorText = String(data: data, encoding: .utf8) ?? ""
            print("   401 Error: \(errorText)")
            throw SuuntoAPIError.unauthorized
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorText = String(data: data, encoding: .utf8) ?? ""
            print("   Error: \(errorText)")
            throw SuuntoAPIError.httpError(statusCode: httpResponse.statusCode)
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SuuntoAPIError.invalidResponse
        }
        
        print("✅ 247 daily data fetched")
        return json
    }
    
    /// Fetch sleep data for a specific date
    func fetchSleepData(date: Date) async throws -> [String: Any]? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)
        
        // Suunto 247 API endpoint for sleep data
        let url = URL(string: "https://cloudapi.suunto.com/v2/247/sleep/\(dateString)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addSuuntoHeaders(to: &request)
        
        print("🔍 Fetching Suunto sleep data for \(dateString)")
        print("   URL: \(url.absoluteString)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SuuntoAPIError.invalidResponse
        }
        
        print("   Status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 404 {
            print("   No sleep data for this date")
            return nil
        }
        
        if httpResponse.statusCode == 401 {
            let errorText = String(data: data, encoding: .utf8) ?? ""
            print("   401 Error: \(errorText)")
            throw SuuntoAPIError.unauthorized
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorText = String(data: data, encoding: .utf8) ?? ""
            print("   Error: \(errorText)")
            throw SuuntoAPIError.httpError(statusCode: httpResponse.statusCode)
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SuuntoAPIError.invalidResponse
        }
        
        print("✅ Sleep data fetched")
        return json
    }
    
    /// Fetch recovery data for a specific date
    func fetchRecoveryData(date: Date) async throws -> [String: Any]? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)
        
        // Suunto 247 API endpoint for recovery data
        let url = URL(string: "https://cloudapi.suunto.com/v2/247/recovery/\(dateString)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addSuuntoHeaders(to: &request)
        
        print("🔍 Fetching Suunto recovery data for \(dateString)")
        print("   URL: \(url.absoluteString)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SuuntoAPIError.invalidResponse
        }
        
        print("   Status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 404 {
            print("   No recovery data for this date")
            return nil
        }
        
        if httpResponse.statusCode == 401 {
            let errorText = String(data: data, encoding: .utf8) ?? ""
            print("   401 Error: \(errorText)")
            throw SuuntoAPIError.unauthorized
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorText = String(data: data, encoding: .utf8) ?? ""
            print("   Error: \(errorText)")
            throw SuuntoAPIError.httpError(statusCode: httpResponse.statusCode)
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SuuntoAPIError.invalidResponse
        }
        
        print("✅ Recovery data fetched")
        return json
    }
    
    /// Fetch all health metrics for a specific date (combines 247 daily, sleep, and recovery)
    func fetchHealthMetrics(date: Date) async throws -> HealthMetrics? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)
        
        print("🔍 Fetching Suunto health metrics for \(dateString)")
        
        // Fetch all three data types
        var dailyData: [String: Any]?
        var sleepData: [String: Any]?
        var recoveryData: [String: Any]?
        
        // Try to fetch daily 247 data (steps, energy, HR)
        do {
            dailyData = try await fetch247DailyData(date: date)
        } catch {
            print("⚠️ Could not fetch 247 daily data: \(error.localizedDescription)")
        }
        
        // Try to fetch sleep data
        do {
            sleepData = try await fetchSleepData(date: date)
        } catch {
            print("⚠️ Could not fetch sleep data: \(error.localizedDescription)")
        }
        
        // Try to fetch recovery data
        do {
            recoveryData = try await fetchRecoveryData(date: date)
        } catch {
            print("⚠️ Could not fetch recovery data: \(error.localizedDescription)")
        }
        
        // If we got no data at all, return nil
        if dailyData == nil && sleepData == nil && recoveryData == nil {
            print("⚠️ No health data available for \(dateString)")
            return nil
        }
        
        // Combine all data into health metrics
        return parseHealthMetrics(dailyData: dailyData, sleepData: sleepData, recoveryData: recoveryData, date: date)
    }
    
    /// Parse health metrics from Suunto 247 API responses
    private func parseHealthMetrics(dailyData: [String: Any]?, sleepData: [String: Any]?, recoveryData: [String: Any]?, date: Date) -> HealthMetrics {
        // Extract from daily 247 data
        let steps = dailyData?["steps"] as? Int ?? dailyData?["totalSteps"] as? Int
        let activeCalories = dailyData?["activeCalories"] as? Int ?? dailyData?["calories"] as? Int
        let restingHR = dailyData?["restingHr"] as? Int ?? 
                       dailyData?["restingHeartRate"] as? Int ??
                       dailyData?["avgRestingHr"] as? Int
        
        // HR data might be in a nested structure
        var hrData: [String: Any]? = dailyData?["hr"] as? [String: Any]
        let avgHR = hrData?["avg"] as? Int ?? dailyData?["avgHr"] as? Int
        let maxHR = hrData?["max"] as? Int ?? dailyData?["maxHr"] as? Int
        let minHR = hrData?["min"] as? Int ?? dailyData?["minHr"] as? Int
        
        // Extract from sleep data
        let sleepDuration = sleepData?["duration"] as? Int ?? sleepData?["sleepDuration"] as? Int
        let sleepScore = sleepData?["sleepScore"] as? Int ?? 
                        sleepData?["quality"] as? Int ??
                        sleepData?["sleepQuality"] as? Int
        let deepSleep = sleepData?["deepSleep"] as? Int ?? sleepData?["deepSleepDuration"] as? Int
        let lightSleep = sleepData?["lightSleep"] as? Int ?? sleepData?["lightSleepDuration"] as? Int
        let remSleep = sleepData?["remSleep"] as? Int ?? sleepData?["remSleepDuration"] as? Int
        let awake = sleepData?["awake"] as? Int ?? sleepData?["awakeDuration"] as? Int
        
        // Extract from recovery data
        let recoveryScore = recoveryData?["recovery"] as? Int ?? 
                          recoveryData?["recoveryScore"] as? Int ??
                          recoveryData?["recoveryStatus"] as? Int
        let recoveryTime = recoveryData?["recoveryTime"] as? Int ?? 
                          recoveryData?["timeToRecovery"] as? Int
        let stress = recoveryData?["stress"] as? Int ?? recoveryData?["stressLevel"] as? Int
        let bodyResources = recoveryData?["bodyResources"] as? Int ?? recoveryData?["resources"] as? Int
        
        // VO2 max might be in recovery or daily data
        let vo2MaxDouble = recoveryData?["vo2Max"] as? Double ?? 
                          dailyData?["vo2Max"] as? Double ??
                          recoveryData?["estimatedVo2Max"] as? Double
        let vo2Max = vo2MaxDouble.map { Decimal($0) }
        
        print("📊 Parsed health metrics:")
        print("   Steps: \(steps ?? 0)")
        print("   Active Calories: \(activeCalories ?? 0)")
        print("   Resting HR: \(restingHR ?? 0)")
        print("   Sleep Score: \(sleepScore ?? 0)")
        print("   Recovery Score: \(recoveryScore ?? 0)")
        print("   VO2 Max: \(vo2Max?.description ?? "N/A")")
        
        return HealthMetrics(
            provider: "suunto",
            date: date,
            vo2Max: vo2Max,
            sleepScore: sleepScore,
            recoveryScore: recoveryScore,
            restingHeartRate: restingHR,
            weightKg: nil, // Weight not typically in 247 API
            caloriesConsumed: activeCalories,
            ageYears: nil,
            fitnessAge: nil
        )
    }
    
    /// Fetch health metrics for a date range
    func fetchHealthMetricsRange(startDate: Date, endDate: Date) async throws -> [HealthMetrics] {
        var metrics: [HealthMetrics] = []
        var currentDate = startDate
        
        while currentDate <= endDate {
            if let metric = try await fetchHealthMetrics(date: currentDate) {
                metrics.append(metric)
            }
            currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate) ?? endDate
        }
        
        return metrics
    }
    
    // MARK: - Training Data
    
    /// Fetch training plans and scheduled workouts from Suunto
    func fetchTrainingPlans(startDate: Date, endDate: Date) async throws -> [TrainingData] {
        // TODO: Implement Suunto Training API integration
        // This is a placeholder - actual implementation requires Suunto API documentation
        throw SuuntoAPIError.notImplemented
    }
}

enum SuuntoAPIError: Error, LocalizedError {
    case notImplemented
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case apiError(message: String)
    case unauthorized
    
    var errorDescription: String? {
        switch self {
        case .notImplemented:
            return "Suunto API integration not yet implemented"
        case .invalidURL:
            return "Invalid URL for Suunto API request"
        case .invalidResponse:
            return "Invalid response from Suunto API"
        case .httpError(let statusCode):
            return "Suunto API HTTP error: \(statusCode)"
        case .apiError(let message):
            return "Suunto API error: \(message)"
        case .unauthorized:
            return "Unauthorized - check your credentials"
        }
    }
}

