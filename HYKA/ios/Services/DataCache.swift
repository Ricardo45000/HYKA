import Foundation

/// Service to cache data locally for offline access
final class DataCache {
    static let shared = DataCache()
    
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    private init() {
        // Create cache directory in app's documents directory
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        cacheDirectory = documentsPath.appendingPathComponent("DataCache", isDirectory: true)
        
        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
        
        print("📦 DataCache initialized at: \(cacheDirectory.path)")
    }
    
    // MARK: - Cache Keys
    
    enum CacheKey: String {
        case racePlans = "race_plans"
        case workouts = "workouts"
        case garminActivities = "garmin_activities"
        case racePlanSegments = "race_plan_segments_"
        case racePlanTrackPoints = "race_plan_track_points_"
        case userProfile = "user_profile"
        case fuelTypes = "fuel_types"
        
        func fileName(userId: UUID? = nil, additionalId: UUID? = nil) -> String {
            var name = rawValue
            if let userId = userId {
                name += "_\(userId.uuidString)"
            }
            if let additionalId = additionalId {
                name += "_\(additionalId.uuidString)"
            }
            return name + ".json"
        }
    }
    
    // MARK: - Save to Cache
    
    /// Save data to cache
    func save<T: Codable>(_ data: T, key: CacheKey, userId: UUID? = nil, additionalId: UUID? = nil) {
        let fileURL = cacheDirectory.appendingPathComponent(key.fileName(userId: userId, additionalId: additionalId))
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let encoded = try encoder.encode(data)
            try encoded.write(to: fileURL)
            print("✅ Cached \(key.rawValue) to: \(fileURL.lastPathComponent)")
        } catch {
            print("❌ Failed to cache \(key.rawValue): \(error)")
        }
    }
    
    /// Save array data to cache
    func saveArray<T: Codable>(_ data: [T], key: CacheKey, userId: UUID? = nil, additionalId: UUID? = nil) {
        save(data, key: key, userId: userId, additionalId: additionalId)
    }
    
    // MARK: - Load from Cache
    
    /// Load data from cache
    func load<T: Codable>(_ type: T.Type, key: CacheKey, userId: UUID? = nil, additionalId: UUID? = nil) -> T? {
        let fileURL = cacheDirectory.appendingPathComponent(key.fileName(userId: userId, additionalId: additionalId))
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            print("ℹ️ No cached data found for \(key.rawValue)")
            return nil
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let decoded = try decoder.decode(T.self, from: data)
            print("✅ Loaded \(key.rawValue) from cache: \(fileURL.lastPathComponent)")
            return decoded
        } catch {
            print("❌ Failed to load cached \(key.rawValue): \(error)")
            return nil
        }
    }
    
    /// Load array data from cache
    func loadArray<T: Codable>(_ type: T.Type, key: CacheKey, userId: UUID? = nil, additionalId: UUID? = nil) -> [T]? {
        return load([T].self, key: key, userId: userId, additionalId: additionalId)
    }
    
    // MARK: - Clear Cache
    
    /// Clear specific cache entry
    func clear(key: CacheKey, userId: UUID? = nil, additionalId: UUID? = nil) {
        let fileURL = cacheDirectory.appendingPathComponent(key.fileName(userId: userId, additionalId: additionalId))
        
        if fileManager.fileExists(atPath: fileURL.path) {
            try? fileManager.removeItem(at: fileURL)
            print("🗑️ Cleared cache for \(key.rawValue)")
        }
    }
    
    /// Clear all cache for a user
    func clearAll(userId: UUID) {
        let userIdString = userId.uuidString
        guard let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) else {
            return
        }
        
        for file in files {
            if file.lastPathComponent.contains(userIdString) {
                try? fileManager.removeItem(at: file)
            }
        }
        print("🗑️ Cleared all cache for user: \(userIdString)")
    }
    
    /// Clear entire cache
    func clearAll() {
        guard let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) else {
            return
        }
        
        for file in files {
            try? fileManager.removeItem(at: file)
        }
        print("🗑️ Cleared entire cache")
    }
    
    // MARK: - Cache Info
    
    /// Get cache size
    func getCacheSize() -> Int64 {
        guard let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        
        var totalSize: Int64 = 0
        for file in files {
            if let attributes = try? file.resourceValues(forKeys: [.fileSizeKey]),
               let size = attributes.fileSize {
                totalSize += Int64(size)
            }
        }
        return totalSize
    }
    
    /// Format cache size for display
    func getCacheSizeFormatted() -> String {
        let size = getCacheSize()
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

