import Foundation

/// Read-only geometric queries over a course polyline.
public struct CourseGeometry: Sendable {
    public let course: Course

    public init(course: Course) {
        self.course = course
    }

    /// The point `distance` meters from the start, interpolating coordinate and
    /// elevation. Binary-searches the precomputed cumulative distances; clamped
    /// to the course ends.
    public func point(atDistance distance: Double) -> TrackPoint {
        let points = course.points
        guard let first = points.first, let last = points.last else {
            return TrackPoint(coordinate: Coordinate(latitude: 0, longitude: 0), distanceFromStart: 0)
        }
        if distance <= first.distanceFromStart { return first }
        if distance >= last.distanceFromStart { return last }

        var low = 0
        var high = points.count - 1
        while high - low > 1 {
            let mid = (low + high) / 2
            if points[mid].distanceFromStart <= distance {
                low = mid
            } else {
                high = mid
            }
        }
        let a = points[low]
        let b = points[high]
        let span = b.distanceFromStart - a.distanceFromStart
        let fraction = span > 0 ? (distance - a.distanceFromStart) / span : 0
        let elevation: Double?
        if let ea = a.elevation, let eb = b.elevation {
            elevation = ea + (eb - ea) * fraction
        } else {
            elevation = a.elevation ?? b.elevation
        }
        return TrackPoint(
            coordinate: GeoMath.interpolate(a.coordinate, b.coordinate, fraction: fraction),
            elevation: elevation,
            distanceFromStart: distance
        )
    }

    public struct SnapResult: Equatable, Sendable {
        /// Nearest point on the course polyline.
        public var coordinate: Coordinate
        /// Course distance of the snapped point.
        public var courseDistance: Double
        /// How far the query location is from the course, meters.
        public var offRouteDistance: Double
    }

    /// Snaps a location onto the nearest polyline *segment* via perpendicular
    /// projection — never merely the nearest raw track point, which on coarse GPX
    /// files lands hundreds of meters off the drawn route.
    public func snap(_ location: Coordinate) -> SnapResult? {
        guard course.points.count >= 2 else { return nil }
        var best: SnapResult?
        for index in 0..<(course.points.count - 1) {
            let candidate = snapToSegment(location, segmentIndex: index)
            if best == nil || candidate.offRouteDistance < (best?.offRouteDistance ?? .infinity) {
                best = candidate
            }
        }
        return best
    }

    /// Every pass of the runner within `radius` meters of a location — one result per
    /// contiguous stretch of course. Out-and-back and lapped courses return several:
    /// a spectator standing still sees the runner once per pass.
    public func passBys(near location: Coordinate, within radius: Double = 75) -> [SnapResult] {
        guard course.points.count >= 2 else { return [] }
        var passes: [SnapResult] = []
        var current: SnapResult?
        for index in 0..<(course.points.count - 1) {
            let candidate = snapToSegment(location, segmentIndex: index)
            if candidate.offRouteDistance <= radius {
                if let existing = current {
                    current = candidate.offRouteDistance < existing.offRouteDistance ? candidate : existing
                } else {
                    current = candidate
                }
            } else if let finished = current {
                passes.append(finished)
                current = nil
            }
        }
        if let finished = current {
            passes.append(finished)
        }
        return passes
    }

    /// A meet point at the given course distance, snapped onto the polyline.
    public func meetPoint(atDistance distance: Double, name: String = "") -> MeetPoint {
        let clamped = min(max(distance, 0), course.totalDistance)
        let track = point(atDistance: clamped)
        return MeetPoint(name: name, coordinate: track.coordinate, courseDistance: clamped)
    }

    /// Perpendicular projection of `location` onto the segment starting at `segmentIndex`,
    /// in a flat plane centered on the location.
    private func snapToSegment(_ location: Coordinate, segmentIndex index: Int) -> SnapResult {
        let a = course.points[index]
        let b = course.points[index + 1]
        let pa = GeoMath.planarOffset(of: a.coordinate, from: location)
        let pb = GeoMath.planarOffset(of: b.coordinate, from: location)
        let dx = pb.x - pa.x
        let dy = pb.y - pa.y
        let lengthSquared = dx * dx + dy * dy
        let t: Double
        if lengthSquared > 0 {
            // The query location is the plane's origin; project (origin − A) onto (B − A).
            t = max(0, min(1, (-pa.x * dx - pa.y * dy) / lengthSquared))
        } else {
            t = 0
        }
        let sx = pa.x + t * dx
        let sy = pa.y + t * dy
        return SnapResult(
            coordinate: GeoMath.interpolate(a.coordinate, b.coordinate, fraction: t),
            courseDistance: a.distanceFromStart + t * (b.distanceFromStart - a.distanceFromStart),
            offRouteDistance: (sx * sx + sy * sy).squareRoot()
        )
    }
}
