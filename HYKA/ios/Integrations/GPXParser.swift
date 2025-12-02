import Foundation

struct GPXTrackPoint {
    let time: Date?
    let lat: Double?
    let lon: Double?
    let ele: Double?
    let hr: Int?
}

final class GPXParser: NSObject, XMLParserDelegate {
    private var points: [GPXTrackPoint] = []
    private var currentElement: String = ""
    private var currentLat: Double?
    private var currentLon: Double?
    private var currentEle: Double?
    private var currentTime: Date?
    private var currentHR: Int?

    func parse(data: Data) -> [GPXTrackPoint] {
        points.removeAll()
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return points
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        if elementName == "trkpt" {
            // Round coordinates to 6 decimal places (~10cm precision) for consistency
            if let latString = attributeDict["lat"], let lat = Double(latString) {
                currentLat = round(lat * 1_000_000.0) / 1_000_000.0
            } else {
                currentLat = nil
            }
            if let lonString = attributeDict["lon"], let lon = Double(lonString) {
                currentLon = round(lon * 1_000_000.0) / 1_000_000.0
            } else {
                currentLon = nil
            }
            currentEle = nil; currentTime = nil; currentHR = nil
            //misses the elevation here
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        switch currentElement {
        case "ele":
            // Round elevation to 1 decimal place (10cm precision) for consistency
            if let ele = Double(trimmed) {
                currentEle = round(ele * 10.0) / 10.0
            } else {
                currentEle = nil
            }
        case "time":
            let iso = ISO8601DateFormatter()
            currentTime = iso.date(from: trimmed)
        case "gpxtpx:hr": currentHR = Int(trimmed)
        default: break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "trkpt" {
            points.append(GPXTrackPoint(time: currentTime, lat: currentLat, lon: currentLon, ele: currentEle, hr: currentHR))
        }
        currentElement = ""
    }
}
