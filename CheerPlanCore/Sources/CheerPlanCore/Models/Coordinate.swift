import Foundation

/// A WGS84 latitude/longitude pair.
public struct Coordinate: Hashable, Codable, Sendable {
    public var latitude: Double
    public var longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    /// Initial bearing toward `other`, degrees clockwise from north —
    /// "walk NE to Spot 3" comes from this.
    public func bearing(toward other: Coordinate) -> Double {
        GeoMath.initialBearing(from: self, to: other)
    }
}
