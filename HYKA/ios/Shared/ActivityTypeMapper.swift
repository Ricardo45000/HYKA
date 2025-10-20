import Foundation
#if canImport(HealthKit)
import HealthKit
#endif

enum ActivityTypeCode: String, Codable {
    case run = "run"
    case trailRun = "trail_run"
    case bike = "bike"
    case swim = "swim"
    case hike = "hike"
    case walk = "walk"
    case row = "row"
    case strength = "strength"
    case yoga = "yoga"
    case other = "other"
}

struct ActivityTypeMapper {
    static func code(for rawType: String?) -> ActivityTypeCode {
        guard let raw = rawType?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return .other
        }
        
        switch raw {
        case "run", "running":
            return .run
        case "trail", "trail run", "trail_running", "trailrun":
            return .trailRun
        case "ride", "bike", "cycling", "cycleride", "virtualride", "virtual_ride":
            return .bike
        case "swim", "swimming":
            return .swim
        case "hike", "hiking":
            return .hike
        case "walk", "walking":
            return .walk
        case "row", "rowing":
            return .row
        case "strength", "strength training", "functional strength training", "traditional strength training":
            return .strength
        case "yoga":
            return .yoga
        default:
            return .other
        }
    }
    
    #if canImport(HealthKit)
    static func code(for hkType: HKWorkoutActivityType) -> ActivityTypeCode {
        switch hkType {
        case .running:
            return .run
        case .hiking:
            return .hike
        case .walking:
            return .walk
        case .cycling:
            return .bike
        case .swimming:
            return .swim
        case .rowing:
            return .row
        case .yoga:
            return .yoga
        case .functionalStrengthTraining, .traditionalStrengthTraining:
            return .strength
        default:
            return .other
        }
    }
    #endif
}

