import CheerPlanCore
import Foundation

public enum ShareCodecError: Error, Equatable, Sendable {
    /// The payload announces a version this build doesn't speak.
    case unsupportedVersion(String)
    case malformedPayload
    /// Not a CheerPlan link at all.
    case notAShareLink
}

/// v1 link payload: the whole plan, with the course simplified for URL transport.
/// Versioned from day one (spec §5).
struct SharePayloadV1: Codable {
    var id: UUID
    var name: String
    var startTime: Date
    var pacing: PacingStrategy
    var courseName: String
    var polyline: String
    /// Meter-rounded elevations, one per polyline point; nil when the course has none.
    var elevations: [Int]?
}

/// Serverless sharing: the link *is* the plan (payload in the URL fragment), and
/// `.cheerplan` files are the full-fidelity offline escape hatch. A hosted
/// redirect/App Clip layer can later wrap these same payloads.
public enum PlanShareCodec {
    public static let linkHost = "cheerplan.app"
    public static let customScheme = "cheerplan"
    public static let fileExtension = "cheerplan"
    static let versionTag = "v1"
    /// Meters of course fidelity given up to make the link small.
    static let simplifyTolerance: Double = 15

    // MARK: - Link

    public static func shareURL(for plan: RunnerPlan) throws -> URL {
        let payload = try makePayload(for: plan)
        let json = try JSONEncoder().encode(payload)
        let fragment = versionTag + "." + base64URLEncode(json)
        guard let url = URL(string: "https://\(linkHost)/p#\(fragment)") else {
            throw ShareCodecError.malformedPayload
        }
        return url
    }

    public static func decodePlan(from url: URL) throws -> RunnerPlan {
        let isCheerPlanLink = url.scheme == customScheme
            || (url.host() == linkHost && (url.scheme == "https" || url.scheme == "http"))
        guard isCheerPlanLink else {
            throw ShareCodecError.notAShareLink
        }
        guard let fragment = url.fragment(percentEncoded: false), !fragment.isEmpty else {
            throw ShareCodecError.malformedPayload
        }
        let parts = fragment.split(separator: ".", maxSplits: 1)
        guard parts.count == 2 else {
            throw ShareCodecError.malformedPayload
        }
        guard parts[0] == versionTag else {
            throw ShareCodecError.unsupportedVersion(String(parts[0]))
        }
        guard let json = base64URLDecode(String(parts[1])),
              let payload = try? JSONDecoder().decode(SharePayloadV1.self, from: json) else {
            throw ShareCodecError.malformedPayload
        }
        return try plan(from: payload)
    }

    // MARK: - .cheerplan file (full fidelity)

    struct FileEnvelope: Codable {
        var version: Int
        var runnerPlan: RunnerPlan
    }

    public static func fileData(for plan: RunnerPlan) throws -> Data {
        try JSONEncoder().encode(FileEnvelope(version: 1, runnerPlan: plan))
    }

    public static func decodePlan(fromFileData data: Data) throws -> RunnerPlan {
        guard let envelope = try? JSONDecoder().decode(FileEnvelope.self, from: data) else {
            throw ShareCodecError.malformedPayload
        }
        guard envelope.version == 1 else {
            throw ShareCodecError.unsupportedVersion("\(envelope.version)")
        }
        return envelope.runnerPlan
    }

    // MARK: - Payload assembly

    private static func makePayload(for plan: RunnerPlan) throws -> SharePayloadV1 {
        let coordinates = plan.course.points.map(\.coordinate)
        let simplified = CourseSimplifier.simplify(coordinates, tolerance: simplifyTolerance)
        var elevations: [Int]?
        if plan.course.hasElevation {
            let geometry = CourseGeometry(course: plan.course)
            elevations = simplified.map { coordinate in
                let distance = geometry.snap(coordinate)?.courseDistance ?? 0
                return Int((geometry.point(atDistance: distance).elevation ?? 0).rounded())
            }
        }
        return SharePayloadV1(
            id: plan.id,
            name: plan.name,
            startTime: plan.startTime,
            pacing: plan.pacing,
            courseName: plan.course.name,
            polyline: PolylineCodec.encode(simplified),
            elevations: elevations
        )
    }

    private static func plan(from payload: SharePayloadV1) throws -> RunnerPlan {
        guard let coordinates = PolylineCodec.decode(payload.polyline) else {
            throw ShareCodecError.malformedPayload
        }
        let pairs: [(coordinate: Coordinate, elevation: Double?)] = coordinates.enumerated().map { index, coordinate in
            if let elevations = payload.elevations, elevations.indices.contains(index) {
                return (coordinate, Double(elevations[index]))
            }
            return (coordinate, nil)
        }
        guard let course = try? Course(name: payload.courseName, coordinates: pairs) else {
            throw ShareCodecError.malformedPayload
        }
        return RunnerPlan(
            id: payload.id,
            name: payload.name,
            course: course,
            startTime: payload.startTime,
            pacing: payload.pacing
        )
    }

    // MARK: - base64url

    static func base64URLEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func base64URLDecode(_ string: String) -> Data? {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 {
            base64.append("=")
        }
        return Data(base64Encoded: base64)
    }
}
