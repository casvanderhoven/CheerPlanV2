import Foundation

public enum CourseError: Error, Equatable, Sendable {
    /// A course needs at least two distinct points.
    case insufficientPoints(found: Int)
}

/// An ordered polyline of track points with precomputed cumulative distances.
public struct Course: Identifiable, Equatable, Codable, Sendable {
    /// Start and finish closer than this are treated as the same place.
    public static let loopThreshold: Double = 50

    public let id: UUID
    public var name: String
    public let points: [TrackPoint]

    /// Builds a course from raw coordinates: removes consecutive duplicate points and
    /// precomputes every `distanceFromStart`. Throws if fewer than two distinct points remain.
    public init(
        id: UUID = UUID(),
        name: String,
        coordinates: [(coordinate: Coordinate, elevation: Double?)]
    ) throws {
        var unique: [(Coordinate, Double?)] = []
        unique.reserveCapacity(coordinates.count)
        for entry in coordinates {
            if let last = unique.last, last.0 == entry.coordinate { continue }
            unique.append((entry.coordinate, entry.elevation))
        }
        guard unique.count >= 2 else {
            throw CourseError.insufficientPoints(found: unique.count)
        }
        var points: [TrackPoint] = []
        points.reserveCapacity(unique.count)
        var cumulative = 0.0
        for (index, entry) in unique.enumerated() {
            if index > 0 {
                cumulative += GeoMath.distance(unique[index - 1].0, entry.0)
            }
            points.append(TrackPoint(coordinate: entry.0, elevation: entry.1, distanceFromStart: cumulative))
        }
        self.id = id
        self.name = name
        self.points = points
    }

    /// Restores a course whose distances were already computed (decoding, tests).
    public init(id: UUID = UUID(), name: String, points: [TrackPoint]) {
        self.id = id
        self.name = name
        self.points = points
    }

    /// Total course length in meters.
    public var totalDistance: Double {
        points.last?.distanceFromStart ?? 0
    }

    public var start: Coordinate? { points.first?.coordinate }
    public var finish: Coordinate? { points.last?.coordinate }

    /// Start and finish within `loopThreshold` — render a combined Start/Finish marker.
    public var isLoop: Bool {
        guard let start, let finish, points.count >= 2 else { return false }
        return GeoMath.distance(start, finish) <= Self.loopThreshold
    }

    public var hasElevation: Bool {
        points.contains { $0.elevation != nil }
    }

    /// Sum of positive elevation deltas, meters. Zero when the file has no elevation.
    public var elevationGain: Double {
        var gain = 0.0
        var previous: Double?
        for point in points {
            guard let elevation = point.elevation else { continue }
            if let last = previous, elevation > last {
                gain += elevation - last
            }
            previous = elevation
        }
        return gain
    }
}
