import Foundation

/// Parser for Garmin .FIT (Flexible and Interoperable Data Transfer) files
/// Reference: https://developer.garmin.com/fit/overview/
/// 
/// .FIT files are binary files with a specific structure:
/// - File header (14 bytes)
/// - Data records (variable length)
/// - CRC (2 bytes)
/// 
/// For production use, consider adding a Swift Package Manager dependency:
/// ```swift
/// dependencies: [
///     .package(url: "https://github.com/roznet/FitFileParser", from: "1.5.2")
/// ]
/// ```
struct FITParser {
    
    /// Parse a .FIT file from Data and extract activity samples
    /// Returns an array of ProviderSample objects with GPS, heart rate, etc.
    /// 
    /// Note: This is a basic implementation. For full .FIT support, use a library like FitFileParser
    static func parse(data: Data) throws -> [ProviderSample] {
        let trackPoints = try parseTrackPoints(data: data)
        
        // Convert FITTrackPoint to ProviderSample
        var startTime: Date?
        return trackPoints.enumerated().map { index, point in
            // Use first timestamp as start time, calculate offset for others
            if startTime == nil, let timestamp = point.timestamp {
                startTime = timestamp
            }
            
            let timeOffset: Int
            if let start = startTime, let timestamp = point.timestamp {
                timeOffset = Int(timestamp.timeIntervalSince(start))
            } else {
                timeOffset = index // Fallback to index if no timestamp
            }
            
            // Calculate pace from speed if available
            let paceSPerKm: Int?
            if let speed = point.speed, speed > 0 {
                paceSPerKm = Int(1000.0 / speed) // seconds per kilometer
            } else {
                paceSPerKm = nil
            }
            
            return ProviderSample(
                tS: timeOffset,
                lat: point.latitude,
                lon: point.longitude,
                altM: point.elevation,
                hr: point.heartRate,
                cadence: point.cadence,
                paceSPerKm: paceSPerKm,
                airTemperatureC: point.temperature,
                speedMPerS: point.speed,
                stepsPerMinute: point.cadence, // Cadence is steps per minute for running
                power: point.power
            )
        }
    }
    
    /// Parse .FIT file and extract track points (GPS coordinates, elevation, heart rate)
    /// This is a basic implementation - full .FIT parsing requires proper message definition parsing
    static func parseTrackPoints(data: Data) throws -> [FITTrackPoint] {
        var trackPoints: [FITTrackPoint] = []
        var offset = 0
        
        // Read file header (14 bytes)
        guard data.count >= 14 else {
            throw FITParseError.invalidFile("File too short")
        }
        
        let headerSize = data[offset]
        guard headerSize == 14 else {
            throw FITParseError.invalidFile("Invalid header size: \(headerSize)")
        }
        offset += 1
        
        // Skip protocol version, profile version
        offset += 2
        
        // Read data size (4 bytes, little-endian)
        let dataSize = UInt32(data[offset]) |
                      (UInt32(data[offset + 1]) << 8) |
                      (UInt32(data[offset + 2]) << 16) |
                      (UInt32(data[offset + 3]) << 24)
        offset += 4
        
        // Skip data type (4 bytes, should be ".FIT")
        offset += 4
        
        // Skip header CRC (2 bytes)
        offset += 2
        
        // Store message definitions (local message type -> message definition)
        var messageDefinitions: [UInt8: FITMessageDefinition] = [:]
        
        // Parse data records
        let dataEnd = offset + Int(dataSize)
        while offset < dataEnd {
            guard offset < data.count else { break }
            
            // Read record header (1 byte)
            let header = data[offset]
            offset += 1
            
            let localMessageType = header & 0x0F
            let isDefinition = (header & 0x40) != 0
            let _ = (header & 0x20) != 0
            
            if isDefinition {
                // Parse definition message
                guard offset + 5 < data.count else { break }
                
                let _ = data[offset]
                offset += 1
                let architecture = data[offset]
                offset += 1
                let isLittleEndian = architecture == 0
                
                // Read global message number (2 bytes)
                let globalMessageNum: UInt16
                if isLittleEndian {
                    globalMessageNum = UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
                } else {
                    globalMessageNum = (UInt16(data[offset]) << 8) | UInt16(data[offset + 1])
                }
                offset += 2
                
                // Read number of fields
                let numFields = Int(data[offset])
                offset += 1
                
                // Read field definitions
                var fields: [FITFieldDefinition] = []
                for _ in 0..<numFields {
                    guard offset + 3 <= data.count else { break }
                    let fieldNum = data[offset]
                    let fieldSize = data[offset + 1]
                    let baseType = data[offset + 2]
                    offset += 3
                    fields.append(FITFieldDefinition(fieldNum: fieldNum, size: fieldSize, baseType: baseType))
                }
                
                messageDefinitions[localMessageType] = FITMessageDefinition(
                    globalMessageNum: globalMessageNum,
                    fields: fields,
                    isLittleEndian: isLittleEndian
                )
            } else {
                // Parse data message
                guard let definition = messageDefinitions[localMessageType] else {
                    // Skip unknown messages
                    continue
                }
                
                // Record message type = 20
                if definition.globalMessageNum == 20 {
                    var timestamp: Date?
                    var latitude: Double?
                    var longitude: Double?
                    var elevation: Double?
                    var heartRate: Int?
                    var cadence: Int?
                    var speed: Double?
                    var power: Int?
                    var temperature: Double?
                    
                    var fieldOffset = 0
                    for field in definition.fields {
                        guard offset + fieldOffset + Int(field.size) <= data.count else { break }
                        
                        let fieldData = data.subdata(in: offset + fieldOffset..<offset + fieldOffset + Int(field.size))
                        
                        // Parse common fields (simplified - full parser needs type handling)
                        switch field.fieldNum {
                        case 253: // timestamp
                            if field.size == 4 {
                                let timestampSeconds = UInt32(fieldData[0]) |
                                    (UInt32(fieldData[1]) << 8) |
                                    (UInt32(fieldData[2]) << 16) |
                                    (UInt32(fieldData[3]) << 24)
                                // Garmin timestamp is seconds since UTC 00:00 Dec 31 1989
                                let garminEpoch = Date(timeIntervalSince1970: 631065600) // Dec 31, 1989
                                timestamp = Date(timeInterval: TimeInterval(timestampSeconds), since: garminEpoch)
                            }
                        case 0: // latitude (semicircles)
                            if field.size == 4 {
                                let semicircles = Int32(fieldData[0]) |
                                    (Int32(fieldData[1]) << 8) |
                                    (Int32(fieldData[2]) << 16) |
                                    (Int32(fieldData[3]) << 24)
                                latitude = Double(semicircles) * (180.0 / 2147483648.0)
                            }
                        case 1: // longitude (semicircles)
                            if field.size == 4 {
                                let semicircles = Int32(fieldData[0]) |
                                    (Int32(fieldData[1]) << 8) |
                                    (Int32(fieldData[2]) << 16) |
                                    (Int32(fieldData[3]) << 24)
                                longitude = Double(semicircles) * (180.0 / 2147483648.0)
                            }
                        case 2: // altitude (meters, with offset)
                            if field.size == 2 {
                                let altitude = UInt16(fieldData[0]) | (UInt16(fieldData[1]) << 8)
                                elevation = Double(altitude) / 5.0 - 500.0 // Scale and offset
                            }
                        case 3: // heart rate (bpm)
                            if field.size == 1 {
                                heartRate = Int(fieldData[0])
                            }
                        case 4: // cadence (rpm)
                            if field.size == 1 {
                                cadence = Int(fieldData[0])
                            }
                        case 6: // speed (m/s, with scale)
                            if field.size == 2 {
                                let speedRaw = UInt16(fieldData[0]) | (UInt16(fieldData[1]) << 8)
                                speed = Double(speedRaw) / 1000.0 // Scale
                            }
                        case 7: // power (watts)
                            if field.size == 2 {
                                power = Int(UInt16(fieldData[0]) | (UInt16(fieldData[1]) << 8))
                            }
                        case 13: // temperature (C, with offset)
                            if field.size == 1 {
                                temperature = Double(Int8(bitPattern: fieldData[0])) + 0.0
                            }
                        default:
                            break
                        }
                        
                        fieldOffset += Int(field.size)
                    }
                    
                    if latitude != nil || longitude != nil || heartRate != nil {
                        trackPoints.append(FITTrackPoint(
                            timestamp: timestamp,
                            latitude: latitude,
                            longitude: longitude,
                            elevation: elevation,
                            heartRate: heartRate,
                            cadence: cadence,
                            speed: speed,
                            power: power,
                            temperature: temperature
                        ))
                    }
                    
                    offset += fieldOffset
                } else {
                    // Skip other message types for now
                    let totalSize = definition.fields.reduce(0) { $0 + Int($1.size) }
                    offset += totalSize
                }
            }
        }
        
        return trackPoints
    }
}

/// Track point from .FIT file
struct FITTrackPoint {
    let timestamp: Date?
    let latitude: Double?
    let longitude: Double?
    let elevation: Double?
    let heartRate: Int?
    let cadence: Int?
    let speed: Double?
    let power: Int?
    let temperature: Double?
}

/// FIT message definition (from definition messages)
private struct FITMessageDefinition {
    let globalMessageNum: UInt16
    let fields: [FITFieldDefinition]
    let isLittleEndian: Bool
}

/// FIT field definition
private struct FITFieldDefinition {
    let fieldNum: UInt8
    let size: UInt8
    let baseType: UInt8
}

enum FITParseError: Error {
    case invalidFile(String)
    case invalidRecord(String)
    case unsupportedFormat(String)
}

/// Note: This is a basic .FIT parser implementation.
/// For production use with full .FIT support, consider using:
/// - https://github.com/roznet/FitFileParser (Swift Package Manager)
/// - Or implement full FIT specification parsing with all message types and field definitions

