import Foundation

/// Health metrics model for all providers
struct HealthMetrics {
    let provider: String
    let date: Date
    let vo2Max: Decimal?
    let sleepScore: Int?
    let recoveryScore: Int?
    let restingHeartRate: Int?
    let weightKg: Decimal?
    let caloriesConsumed: Int?
    let ageYears: Int?
    let fitnessAge: Decimal?
}

/// Protocol for providers that can fetch health metrics
protocol HealthMetricsProvider {
    func fetchHealthMetrics(accessToken: String, date: Date) async throws -> HealthMetrics?
    func fetchHealthMetricsRange(accessToken: String, startDate: Date, endDate: Date) async throws -> [HealthMetrics]
}

