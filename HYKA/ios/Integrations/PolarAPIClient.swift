import Foundation

/// Client for fetching data from Polar Flow API
final class PolarAPIClient {
    private let accessToken: String
    
    init(accessToken: String) {
        self.accessToken = accessToken
    }
    
    /// Fetch list of exercises (activities) from Polar
    /// Reference: https://www.polar.com/accesslink-api/#list-exercises
    func fetchActivities(after: Date? = nil) async throws -> [PolarActivity] {
        let baseURL = "https://www.polaraccesslink.com/v3"
        var components = URLComponents(string: "\(baseURL)/exercises")!
        
        // Add query parameters
        var queryItems: [URLQueryItem] = []
        
        if let after = after {
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            queryItems.append(URLQueryItem(name: "start", value: dateFormatter.string(from: after)))
        }
        
        // Optional: Add limit if needed (default is 100)
        // queryItems.append(URLQueryItem(name: "limit", value: "100"))
        
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        
        guard let url = components.url else {
            throw PolarAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        print("🔄 Fetching Polar exercises from: \(url.absoluteString)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PolarAPIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorData = String(data: data, encoding: .utf8) ?? "Unable to decode error"
            print("❌ Polar exercises API error (status \(httpResponse.statusCode)): \(errorData)")
            throw PolarAPIError.httpError(statusCode: httpResponse.statusCode)
        }
        
        // Parse JSON response
        // Polar returns an array of exercises
        do {
            let decoder = JSONDecoder()
            // Note: We use CodingKeys for snake_case conversion, so don't set keyDecodingStrategy
            let exercises = try decoder.decode([PolarActivity].self, from: data)
            print("✅ Parsed \(exercises.count) Polar exercises")
            return exercises
        } catch {
            // Fallback: try manual parsing if decoder fails
            print("⚠️ JSONDecoder failed, trying manual parsing: \(error)")
            print("   Error details: \(error.localizedDescription)")
            
            // Log the raw response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("   Raw response (first 500 chars): \(String(responseString.prefix(500)))")
            }
            
            guard let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                print("❌ Failed to parse exercises JSON")
                throw PolarAPIError.invalidResponse
            }
            
            var activities: [PolarActivity] = []
            for json in jsonArray {
                // Try to decode individual exercise
                if let jsonData = try? JSONSerialization.data(withJSONObject: json) {
                    let decoder = JSONDecoder()
                    if let activity = try? decoder.decode(PolarActivity.self, from: jsonData) {
                        activities.append(activity)
                    } else {
                        print("⚠️ Failed to decode individual exercise: \(json.keys.joined(separator: ", "))")
                    }
                }
            }
            
            print("✅ Manually parsed \(activities.count) Polar exercises")
            return activities
        }
    }
    
    /// Fetch detailed activity information
    func fetchActivity(activityId: String) async throws -> PolarActivity {
        // TODO: Implement
        throw PolarAPIError.notImplemented
    }
    
    /// Fetch activity streams (GPS, HR, cadence, etc.)
    func fetchStreams(activityId: String) async throws -> [ProviderSample] {
        // TODO: Implement
        throw PolarAPIError.notImplemented
    }
    
    /// Fetch activity laps
    func fetchLaps(activityId: String) async throws -> [ProviderLap] {
        // TODO: Implement
        throw PolarAPIError.notImplemented
    }
    
    // MARK: - Health Metrics
    
    /// Fetch health metrics for a specific date
    func fetchHealthMetrics(date: Date) async throws -> HealthMetrics? {
        // Polar Flow API endpoint for daily health data
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]
        let dateString = dateFormatter.string(from: date)
        
        // Polar Flow API endpoint
        let url = URL(string: "https://www.polaraccesslink.com/v3/users/daily-summary/\(dateString)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PolarAPIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 404 {
                return nil
            }
            throw PolarAPIError.httpError(statusCode: httpResponse.statusCode)
        }
        
        // Parse Polar health data
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PolarAPIError.invalidResponse
        }
        
        // Extract metrics from Polar response
        // Note: Field names may vary based on Polar's actual API response
        let vo2Max = (json["vo2Max"] as? Double ?? json["vo2_max"] as? Double).map { Decimal($0) }
        let sleepScore = json["sleepScore"] as? Int ?? json["sleep_score"] as? Int
        let recoveryScore = json["recoveryScore"] as? Int ?? json["recovery_score"] as? Int ?? json["recoveryStatus"] as? Int
        let restingHR = json["restingHeartRate"] as? Int ?? json["resting_heart_rate"] as? Int ?? json["restingHR"] as? Int
        let weight = (json["weight"] as? Double).map { Decimal($0) }
        let calories = json["caloriesConsumed"] as? Int ?? json["totalCalories"] as? Int
        
        let ageYears = json["age"] as? Int ?? json["ageYears"] as? Int
        let fitnessAgeValue: Decimal?
        if let fitnessAgeDouble = json["fitnessAge"] as? Double ?? json["fitness_age"] as? Double {
            fitnessAgeValue = Decimal(fitnessAgeDouble)
        } else {
            fitnessAgeValue = nil
        }
        
        return HealthMetrics(
            provider: "polar",
            date: date,
            vo2Max: vo2Max,
            sleepScore: sleepScore,
            recoveryScore: recoveryScore,
            restingHeartRate: restingHR,
            weightKg: weight,
            caloriesConsumed: calories,
            ageYears: ageYears,
            fitnessAge: fitnessAgeValue
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
    
    /// Fetch training plans and scheduled workouts from Polar
    /// Note: Polar API does not support scheduled training plans - only completed exercises
    /// Use fetchActivities() to get completed workouts
    func fetchTrainingPlans(startDate: Date, endDate: Date) async throws -> [TrainingData] {
        // Polar API does not have an endpoint for scheduled training plans
        // They only provide completed exercises via the /exercises endpoint
        // Return empty array - this is expected behavior for Polar
        print("ℹ️ Polar API does not support scheduled training plans - only completed exercises")
        return []
    }
}

enum PolarAPIError: Error, LocalizedError {
    case notImplemented
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case apiError(message: String)
    case unauthorized
    
    var errorDescription: String? {
        switch self {
        case .notImplemented:
            return "Polar API integration not yet implemented"
        case .invalidURL:
            return "Invalid URL for Polar API request"
        case .invalidResponse:
            return "Invalid response from Polar API"
        case .httpError(let statusCode):
            return "Polar API HTTP error: \(statusCode)"
        case .apiError(let message):
            return "Polar API error: \(message)"
        case .unauthorized:
            return "Unauthorized - check your credentials"
        }
    }
}


