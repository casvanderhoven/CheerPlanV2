import Foundation

/// A viewing spot snapped onto the course polyline.
///
/// `courseDistance` identifies *which pass* of the runner this spot watches: on
/// out-and-back or lapped courses the same physical coordinate maps to several
/// course distances, and each is a distinct sighting.
public struct MeetPoint: Identifiable, Equatable, Codable, Sendable {
    public let id: UUID
    public var name: String
    /// Position on the course polyline (already snapped).
    public var coordinate: Coordinate
    /// Meters from the course start for the watched pass.
    public var courseDistance: Double

    public init(id: UUID = UUID(), name: String = "", coordinate: Coordinate, courseDistance: Double) {
        self.id = id
        self.name = name
        self.coordinate = coordinate
        self.courseDistance = courseDistance
    }
}
