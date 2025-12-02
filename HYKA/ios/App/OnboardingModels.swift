import Foundation

// MARK: - Onboarding Data Models

struct RaceDetails {
    let name: String
    let date: Date
    let startTime: Date
    let distance: Double // in kilometers
    let elevation: Int // in meters
    let difficulty: String
}

struct AidStation: Identifiable, Codable {
    let id: UUID
    let name: String
    let distance: Double // in kilometers
    let services: [AidService]
    
    init(id: UUID = UUID(), name: String, distance: Double, services: [AidService]) {
        self.id = id
        self.name = name
        self.distance = distance
        self.services = services
    }
}

struct AidService: Codable {
    let type: ServiceType
    let isAvailable: Bool
    
    enum ServiceType: String, CaseIterable, Codable {
        case hydration = "Hydration"
        case gels = "Gels"
        case food = "Food"
        case crew = "Crew"
        
        var icon: String {
            switch self {
            case .hydration: return "drop.fill"
            case .gels: return "bolt.fill"
            case .food: return "fork.knife"
            case .crew: return "person.2.fill"
            }
        }
    }
}

struct StrategyPreferences {
    var raceGoals: [RaceGoal] = []
    var nutritionPreferences: [NutritionPreference] = []
    
    enum RaceGoal: String, CaseIterable {
        case finish = "Finish the race"
        case timeGoal = "Hit a specific time goal"
        case podium = "Compete for podium/placement"
        case experience = "Enjoy the experience"
    }
    
    enum NutritionPreference: String, CaseIterable {
        case gels = "Energy gels and chews"
        case realFood = "Real Food (bars, sandwiches, etc.)"
        case mix = "Mix of both"
    }
}

struct UserProfile {
    var firstName: String = ""
    var lastName: String = ""
    var birthDate: Date = Date()
    var gender: Gender = .preferNotToSay
    var runningDistances: [RunningDistance] = []
    var experienceLevel: ExperienceLevel = .beginner
    var customDistance: String = ""
    
    enum Gender: String, CaseIterable {
        case male = "Male"
        case female = "Female"
        case nonBinary = "Non-binary"
        case preferNotToSay = "Prefer not to say"
    }
    
    enum RunningDistance: String, CaseIterable {
        case twentyK = "20K"
        case fiftyK = "50K"
        case fiftyM = "50M"
        case hundredK = "100K"
        case hundredM = "100M"
        case multiDay = "Multi Day"
        case other = "Other"
        
        var icon: String {
            switch self {
            case .twentyK, .fiftyK, .other:
                return "figure.run"
            case .fiftyM, .hundredK, .hundredM:
                return "mountain.2"
            case .multiDay:
                return "flame"
            }
        }
    }
    
    enum ExperienceLevel: String, CaseIterable {
        case beginner = "Beginner"
        case intermediate = "Intermediate"
        case advanced = "Advanced"
        
        var description: String {
            switch self {
            case .beginner:
                return "First ultra or training for one"
            case .intermediate:
                return "1-5 ultra races completed"
            case .advanced:
                return "5+ ultra races completed"
            }
        }
    }
}

struct PacingStrategy {
    let phase: String
    let paceRange: String
    let description: String
}

struct NutritionPlan {
    let preRace: String
    let duringRace: String
    let caloriesPerHour: Int
    let hydrationPerHour: Int
}

struct DeviceConnection {
    let name: String
    let icon: String
    let isConnected: Bool
}

// MARK: - Mock Data

extension RaceDetails {
    static let mock = RaceDetails(
        name: "UTMB",
        date: Calendar.current.date(from: DateComponents(year: 2026, month: 8, day: 21)) ?? Date(),
        startTime: Calendar.current.date(from: DateComponents(hour: 6, minute: 0)) ?? Date(),
        distance: 50.0,
        elevation: 2400,
        difficulty: "Hard"
    )
}

extension PacingStrategy {
    static let mock = [
        PacingStrategy(phase: "Start Easy", paceRange: "8:30–9:00", description: "Warm up and find your rhythm"),
        PacingStrategy(phase: "Steady Climb", paceRange: "9:30–10:00", description: "Maintain effort on uphills"),
        PacingStrategy(phase: "Push the Pace", paceRange: "8:00–8:30", description: "Strong finish on downhills")
    ]
}

extension NutritionPlan {
    static let mock = NutritionPlan(
        preRace: "Light breakfast + hydration (-2h)",
        duringRace: "Every 45min • Energy gel + 250ml water",
        caloriesPerHour: 280,
        hydrationPerHour: 500
    )
}

extension DeviceConnection {
    static let mock = [
        DeviceConnection(name: "Garmin", icon: "GarminIcon", isConnected: false),
        DeviceConnection(name: "Strava", icon: "StravaIcon", isConnected: false),
        DeviceConnection(name: "Polar", icon: "PolarIcon", isConnected: false),
        DeviceConnection(name: "Coros", icon: "CorosIcon", isConnected: false),
        DeviceConnection(name: "Suunto", icon: "SuuntoIcon", isConnected: false)
    ]
}

extension AidStation {
    static let mock = [
        AidStation(name: "Start", distance: 0, services: [
            AidService(type: .hydration, isAvailable: true),
            AidService(type: .gels, isAvailable: true),
            AidService(type: .food, isAvailable: true),
            AidService(type: .crew, isAvailable: true)
        ]),
        AidStation(name: "Finish", distance: 100, services: [
            AidService(type: .hydration, isAvailable: true),
            AidService(type: .gels, isAvailable: true),
            AidService(type: .food, isAvailable: true),
            AidService(type: .crew, isAvailable: true)
        ])
    ]
}
