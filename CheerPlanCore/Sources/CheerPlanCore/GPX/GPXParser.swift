import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

public enum GPXError: Error, Equatable, Sendable {
    /// The data is not well-formed XML.
    case invalidXML(description: String)
    /// Well-formed XML, but no `<trkpt>` or `<rtept>` found.
    case noTrack
    /// Fewer than two distinct points after removing duplicates.
    case insufficientPoints(found: Int)
}

/// Parses GPX 1.0/1.1 into a `Course`.
///
/// Handles the realities of files in the wild: `<trk>` and `<rte>` variants, sparse
/// points, missing elevation on some or all points, and consecutive duplicate points.
/// Every failure is a typed `GPXError` — nothing is swallowed.
public enum GPXParser {
    public static func parseCourse(from data: Data, name: String? = nil) throws -> Course {
        let delegate = GPXDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse() else {
            let description = parser.parserError.map { String(describing: $0) } ?? "malformed XML"
            throw GPXError.invalidXML(description: description)
        }
        guard !delegate.points.isEmpty else {
            throw GPXError.noTrack
        }
        do {
            let courseName = name ?? delegate.courseName ?? "Imported course"
            return try Course(name: courseName, coordinates: delegate.points)
        } catch CourseError.insufficientPoints(let found) {
            throw GPXError.insufficientPoints(found: found)
        }
    }

    public static func parseCourse(from string: String, name: String? = nil) throws -> Course {
        try parseCourse(from: Data(string.utf8), name: name)
    }
}

/// Streaming XML delegate collecting `<trkpt>`/`<rtept>` coordinates and elevations.
private final class GPXDelegate: NSObject, XMLParserDelegate {
    var points: [(coordinate: Coordinate, elevation: Double?)] = []
    var courseName: String?

    private var currentLatitude: Double?
    private var currentLongitude: Double?
    private var currentElevation: Double?
    private var insidePoint = false
    private var capturingText = false
    private var textBuffer = ""

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String]
    ) {
        switch elementName {
        case "trkpt", "rtept":
            insidePoint = true
            currentLatitude = attributeDict["lat"].flatMap(Double.init)
            currentLongitude = attributeDict["lon"].flatMap(Double.init)
            currentElevation = nil
        case "ele" where insidePoint:
            capturingText = true
            textBuffer = ""
        case "name" where !insidePoint && courseName == nil:
            capturingText = true
            textBuffer = ""
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if capturingText {
            textBuffer += string
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        switch elementName {
        case "trkpt", "rtept":
            if let latitude = currentLatitude, let longitude = currentLongitude {
                points.append((Coordinate(latitude: latitude, longitude: longitude), currentElevation))
            }
            insidePoint = false
        case "ele" where insidePoint:
            currentElevation = Double(textBuffer.trimmingCharacters(in: .whitespacesAndNewlines))
            capturingText = false
        case "name":
            if capturingText {
                let trimmed = textBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty, courseName == nil {
                    courseName = trimmed
                }
            }
            capturingText = false
        default:
            break
        }
    }
}
