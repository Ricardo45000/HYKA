import Foundation
import Auth

/// Unified service for fetching workout data from all providers (Garmin, Coros, Suunto, Polar)
/// and storing it in Supabase
@MainActor
final class WorkoutDataFetchingService {
    
    // MARK: - Fetch Workouts from Provider
    
    /// Fetch all workouts from a specific provider and store in Supabase
    /// If `after` is nil, will use incremental sync (fetch only new activities since last sync)
    /// If `after` is provided, will fetch activities after that date
    func fetchAndStoreWorkouts(
        userId: UUID,
        provider: String,
        accessToken: String,
        tokenSecret: String? = nil, // OAuth 1.0a token secret (for other providers)
        after: Date? = nil,
        useIncrementalSync: Bool = true
    ) async throws -> Int {
        print("🔄 Fetching workouts for provider: \(provider)")
        
        // Determine the date to fetch from
        let fetchAfter: Date?
        if let providedAfter = after {
            fetchAfter = providedAfter
            print("📅 Using provided date: \(providedAfter)")
        } else if useIncrementalSync {
            // Try to get last sync timestamp from Supabase
            if let lastTimestamp = try? await SupabaseService.getLastWorkoutTimestamp(userId: userId, provider: provider) {
                fetchAfter = lastTimestamp
                print("📅 Incremental sync: Fetching activities after \(lastTimestamp)")
            } else {
                // No previous workouts - fetch last 7 days only
                fetchAfter = Date().addingTimeInterval(-7 * 24 * 60 * 60)
                print("📅 No previous workouts found - fetching last 7 days only")
            }
        } else {
            // Full historical sync - fetch ALL activities (from 1 year ago to now)
            // This is used when user explicitly clicks "Sync with device" button
            fetchAfter = Date().addingTimeInterval(-365 * 24 * 60 * 60) // 1 year ago
            print("📅 Full historical sync: Fetching ALL activities from the past year")
            print("   This may take longer but will get all historical activities")
        }
        
        var workoutsFetched = 0
        
        switch provider.lowercased() {
        case "garmin":
            // Garmin data is now fetched SERVER-SIDE via Supabase Edge Functions
            // iOS app no longer pulls activity data directly from Garmin APIs
            // 
            // Architecture:
            // 1. Garmin sends push/ping notifications → Edge Function webhook
            // 2. Edge Function fetches activity details using Pull Token (server-side)
            // 3. Edge Function stores activities in Supabase (garmin_activities table)
            // 4. iOS app reads from Supabase (not from Garmin APIs)
            //
            // This method is deprecated for Garmin - data is pulled automatically by backend
            print("ℹ️  Garmin data is fetched automatically by backend via webhooks")
            print("   No client-side data fetching needed for Garmin")
            print("   Activities are available in Supabase garmin_activities table")
            return 0 // No activities fetched client-side
            
        case "coros":
            // TODO: Implement Coros fetching when API client is ready
            print("⚠️ Coros API not yet implemented")
            throw WorkoutFetchError.providerNotImplemented("coros")
            
        case "suunto":
            // TODO: Implement Suunto fetching when API client is ready
            print("⚠️ Suunto API not yet implemented")
            throw WorkoutFetchError.providerNotImplemented("suunto")
            
        case "polar":
            // Polar uses OAuth 2.0 with Bearer tokens
            // Note: Polar activities API is not fully implemented yet
            do {
                let client = PolarAPIClient(accessToken: accessToken)
                let activities = try await client.fetchActivities(after: after)
                
                print("✅ Fetched \(activities.count) Polar activities")
                
                if activities.isEmpty {
                    print("ℹ️ No Polar activities found (API may not be fully implemented yet)")
                }
                
                for activity in activities {
                    do {
                        guard let workout = activity.toProviderWorkout() else {
                            print("⚠️ Skipping activity - unable to convert to workout")
                            continue
                        }
                        
                        // Check if workout already exists
                        let existingWorkout = try await SupabaseService.fetchWorkoutByProviderId(
                            userId: userId,
                            provider: "polar",
                            providerActivityId: workout.providerActivityId
                        )
                        
                        if existingWorkout == nil {
                            // Store workout in Supabase
                            let workoutId = try await SupabaseService.saveWorkout(
                                userId: userId,
                                workout: workout,
                                provider: "polar"
                            )
                            
                            print("✅ Stored workout: \(workout.name ?? "Untitled")")
                            
                            // Fetch and store samples (streams) for this workout
                            if let activityId = activity.activityId {
                                try await fetchAndStoreSamples(
                                    userId: userId,
                                    workoutId: workoutId,
                                    provider: "polar",
                                    activityId: activityId
                                )
                            }
                            
                            workoutsFetched += 1
                        } else {
                            print("⏭️ Skipping duplicate workout: \(workout.name ?? "Untitled")")
                        }
                    } catch {
                        print("⚠️ Error processing workout: \(error)")
                        // Continue with next workout
                    }
                }
            } catch {
                // Don't fail the connection if activities fetching isn't implemented
                print("⚠️ Polar activities fetching not yet fully implemented: \(error)")
                print("   Connection will still be saved, but workouts won't be synced yet")
            }
            
        default:
            throw WorkoutFetchError.unknownProvider(provider)
        }
        
        print("✅ Completed fetching workouts for \(provider): \(workoutsFetched) new workouts")
        return workoutsFetched
    }
    
    // MARK: - Fetch Samples (Streams)
    
    /// Fetch and store samples/streams for a specific workout
    private func fetchAndStoreSamples(
        userId: UUID,
        workoutId: UUID,
        provider: String,
        activityId: String,
        activityStartTime: String? = nil,
        activityDuration: Int? = nil
    ) async throws {
        print("🔄 Fetching samples for workout \(workoutId)")
        
        switch provider.lowercased() {
        case "garmin":
            // Garmin samples are now fetched SERVER-SIDE via Edge Functions
            // iOS app no longer pulls sample data directly from Garmin APIs
            print("ℹ️  Garmin samples are fetched automatically by backend")
            print("   No client-side sample fetching needed for Garmin")
            print("   Read from Supabase garmin_activity_samples table")
            return
            
        case "coros", "suunto":
            print("⚠️ Sample fetching not yet implemented for \(provider)")
            
        case "polar":
            // Polar sample fetching not yet implemented
            print("⚠️ Polar sample fetching not yet implemented")
            
        default:
            throw WorkoutFetchError.unknownProvider(provider)
        }
    }
    
    // MARK: - Sync All Providers
    
    /// Sync workouts from all connected providers
    func syncAllProviders(userId: UUID) async throws -> [String: Int] {
        print("🔄 Starting sync for all connected providers")
        
        var results: [String: Int] = [:]
        
        // Fetch all OAuth connections for this user
        let connections = try await SupabaseService.fetchOAuthConnections(userId: userId)
        
        for connection in connections {
            // Check if token exists (not empty) and is not expired
            guard !connection.accessToken.isEmpty,
                  let expiresAt = connection.expiresAt,
                  expiresAt > Date() else {
                print("⚠️ Skipping \(connection.provider) - token expired or missing")
                continue
            }
            
            do {
                let count = try await fetchAndStoreWorkouts(
                    userId: userId,
                    provider: connection.provider,
                    accessToken: connection.accessToken
                )
                results[connection.provider] = count
            } catch {
                print("❌ Error syncing \(connection.provider): \(error)")
                results[connection.provider] = 0
            }
        }
        
        return results
    }
    
    // MARK: - Health Metrics
    
    /// Fetch and store health metrics from a provider
    func fetchAndStoreHealthMetrics(
        userId: UUID,
        provider: String,
        accessToken: String,
        startDate: Date,
        endDate: Date
    ) async throws {
        print("🔄 Fetching health metrics for provider: \(provider)")
        
        var metricsFetched = 0
        
        switch provider.lowercased() {
        case "garmin":
            // Garmin health metrics are now fetched SERVER-SIDE via Edge Functions
            // iOS app no longer pulls health data directly from Garmin APIs
            print("ℹ️  Garmin health metrics are fetched automatically by backend")
            print("   No client-side health data fetching needed for Garmin")
            return
            
        case "coros":
            let client = CorosAPIClient(accessToken: accessToken)
            let metrics = try await client.fetchHealthMetricsRange(startDate: startDate, endDate: endDate)
            
            print("✅ Fetched \(metrics.count) Coros health metrics")
            
            for metric in metrics {
                do {
                    print("💾 Pushing health metric to database: date=\(metric.date), vo2Max=\(metric.vo2Max?.description ?? "nil"), sleepScore=\(metric.sleepScore?.description ?? "nil"), recoveryScore=\(metric.recoveryScore?.description ?? "nil"), restingHR=\(metric.restingHeartRate?.description ?? "nil"), weight=\(metric.weightKg?.description ?? "nil"), calories=\(metric.caloriesConsumed?.description ?? "nil")")
                    
                    try await SupabaseService.saveHealthMetrics(
                        userId: userId,
                        provider: "coros",
                        metrics: metric
                    )
                    
                    print("✅ Health metric saved to database for date: \(metric.date)")
                    metricsFetched += 1
                } catch {
                    print("⚠️ Error saving health metric to database: \(error)")
                }
            }
            
        case "suunto":
            let client = SuuntoAPIClient(accessToken: accessToken)
            let metrics = try await client.fetchHealthMetricsRange(startDate: startDate, endDate: endDate)
            
            print("✅ Fetched \(metrics.count) Suunto health metrics")
            
            for metric in metrics {
                do {
                    print("💾 Pushing health metric to database: date=\(metric.date), vo2Max=\(metric.vo2Max?.description ?? "nil"), sleepScore=\(metric.sleepScore?.description ?? "nil"), recoveryScore=\(metric.recoveryScore?.description ?? "nil"), restingHR=\(metric.restingHeartRate?.description ?? "nil"), weight=\(metric.weightKg?.description ?? "nil"), calories=\(metric.caloriesConsumed?.description ?? "nil")")
                    
                    try await SupabaseService.saveHealthMetrics(
                        userId: userId,
                        provider: "suunto",
                        metrics: metric
                    )
                    
                    print("✅ Health metric saved to database for date: \(metric.date)")
                    metricsFetched += 1
                } catch {
                    print("⚠️ Error saving health metric to database: \(error)")
                }
            }
            
        case "polar":
            let client = PolarAPIClient(accessToken: accessToken)
            let metrics = try await client.fetchHealthMetricsRange(startDate: startDate, endDate: endDate)
            
            print("✅ Fetched \(metrics.count) Polar health metrics")
            
            for metric in metrics {
                do {
                    print("💾 Pushing health metric to database: date=\(metric.date), vo2Max=\(metric.vo2Max?.description ?? "nil"), sleepScore=\(metric.sleepScore?.description ?? "nil"), recoveryScore=\(metric.recoveryScore?.description ?? "nil"), restingHR=\(metric.restingHeartRate?.description ?? "nil"), weight=\(metric.weightKg?.description ?? "nil"), calories=\(metric.caloriesConsumed?.description ?? "nil")")
                    
                    try await SupabaseService.saveHealthMetrics(
                        userId: userId,
                        provider: "polar",
                        metrics: metric
                    )
                    
                    print("✅ Health metric saved to database for date: \(metric.date)")
                    metricsFetched += 1
                } catch {
                    print("⚠️ Error saving health metric to database: \(error)")
                }
            }
            
        default:
            print("⚠️ Unknown provider for health metrics: \(provider)")
        }
        
        print("✅ Completed fetching health metrics for \(provider): \(metricsFetched) new metrics")
    }
    
    // MARK: - Fetch Training Data
    
    /// Fetch training plans and scheduled workouts from a provider and store in Supabase
    func fetchAndStoreTraining(
        userId: UUID,
        provider: String,
        accessToken: String,
        startDate: Date? = nil,
        endDate: Date? = nil
    ) async throws -> Int {
        print("🔄 Fetching training data for provider: \(provider)")
        
        var trainingFetched = 0
        
        // Default to next 30 days if no date range provided
        let endDate = endDate ?? Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
        let startDate = startDate ?? Date()
        
        switch provider.lowercased() {
        case "garmin":
            // Garmin training data is now fetched SERVER-SIDE via Edge Functions
            // iOS app no longer pulls training data directly from Garmin APIs
            print("ℹ️  Garmin training data is fetched automatically by backend")
            print("   No client-side training data fetching needed for Garmin")
            return 0
            
        case "coros":
            do {
                let client = CorosAPIClient(accessToken: accessToken)
                let trainingData = try await client.fetchTrainingPlans(startDate: startDate, endDate: endDate)
                
                print("✅ Fetched \(trainingData.count) Coros training items")
                
                for training in trainingData {
                    do {
                        try await SupabaseService.saveTraining(
                            userId: userId,
                            provider: "coros",
                            trainingData: training
                        )
                        trainingFetched += 1
                    } catch {
                        print("⚠️ Error saving training data: \(error)")
                    }
                }
            } catch {
                print("⚠️ Coros training API not yet implemented: \(error)")
            }
            
        case "suunto":
            do {
                let client = SuuntoAPIClient(accessToken: accessToken)
                let trainingData = try await client.fetchTrainingPlans(startDate: startDate, endDate: endDate)
                
                print("✅ Fetched \(trainingData.count) Suunto training items")
                
                for training in trainingData {
                    do {
                        try await SupabaseService.saveTraining(
                            userId: userId,
                            provider: "suunto",
                            trainingData: training
                        )
                        trainingFetched += 1
                    } catch {
                        print("⚠️ Error saving training data: \(error)")
                    }
                }
            } catch {
                print("⚠️ Suunto training API not yet implemented: \(error)")
            }
            
        case "polar":
            do {
                let client = PolarAPIClient(accessToken: accessToken)
                let trainingData = try await client.fetchTrainingPlans(startDate: startDate, endDate: endDate)
                
                print("✅ Fetched \(trainingData.count) Polar training items")
                
                for training in trainingData {
                    do {
                        try await SupabaseService.saveTraining(
                            userId: userId,
                            provider: "polar",
                            trainingData: training
                        )
                        trainingFetched += 1
                    } catch {
                        print("⚠️ Error saving training data: \(error)")
                    }
                }
            } catch {
                print("⚠️ Polar training API not yet implemented: \(error)")
            }
            
        default:
            print("⚠️ Unknown provider for training data: \(provider)")
        }
        
        print("✅ Completed fetching training data for \(provider): \(trainingFetched) new training items")
        return trainingFetched
    }
}

// MARK: - Errors

enum WorkoutFetchError: Error, LocalizedError {
    case unknownProvider(String)
    case providerNotImplemented(String)
    case noAccessToken
    case invalidActivityId
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .unknownProvider(let provider):
            return "Unknown provider: \(provider)"
        case .providerNotImplemented(let provider):
            return "\(provider) API integration not yet implemented"
        case .noAccessToken:
            return "No access token available"
        case .invalidActivityId:
            return "Invalid activity ID"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

