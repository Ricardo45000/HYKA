import Foundation

struct RacePlan: Identifiable {
    let id: UUID
    var title: String
    var segments: [RaceSegment]
    var fuel: [FuelEvent]
}

struct RaceSegment: Identifiable {
    let id = UUID()
    var distanceMeters: Double
    var targetPaceSecPerKm: Int
    var notes: String?
}

struct FuelEvent: Identifiable {
    let id = UUID()
    var minute: Int
    var carbsGrams: Int
    var notes: String?
}

extension RacePlan {
    static func demo() -> RacePlan {
        RacePlan(id: UUID(), title: "UTCC 120", segments: [
            RaceSegment(distanceMeters: 10000, targetPaceSecPerKm: 330, notes: "Warm start"),
            RaceSegment(distanceMeters: 20000, targetPaceSecPerKm: 360, notes: "Climb steady"),
        ], fuel: [
            FuelEvent(minute: 30, carbsGrams: 30, notes: "Gel 1"),
            FuelEvent(minute: 60, carbsGrams: 30, notes: "Gel 2"),
        ])
    }
}
