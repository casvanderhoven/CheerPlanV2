import Foundation

/// One point of a course polyline.
public struct TrackPoint: Hashable, Codable, Sendable {
    public var coordinate: Coordinate
    /// Meters above sea level, when the source file provides it.
    public var elevation: Double?
    /// Meters from the course start, precomputed once at course construction.
    /// All point-at-distance queries binary-search this — never recompute haversines.
    public var distanceFromStart: Double

    public init(coordinate: Coordinate, elevation: Double? = nil, distanceFromStart: Double) {
        self.coordinate = coordinate
        self.elevation = elevation
        self.distanceFromStart = distanceFromStart
    }
}
