import Foundation

struct Workout: Identifiable, Codable {
    let id: UUID
    let name: String?
    let distance_m: Double?
    let elapsed_seconds: Int?
    let activity_type_code: ActivityTypeCode?
    let start_timezone_offset_minutes: Int?

    var distanceKmString: String {
        let km = (distance_m ?? 0)/1000.0
        return String(format: "%.1f km", km)
    }
    var elapsedString: String {
        let s = elapsed_seconds ?? 0
        let h = s/3600, m = (s%3600)/60
        return String(format: "%dh %dm", h, m)
    }
}
