import Foundation

/// Douglas–Peucker polyline simplification — share links carry a course sketch,
/// not two thousand raw track points.
public enum CourseSimplifier {
    /// Keeps every point that deviates more than `tolerance` meters from the
    /// simplified line. Endpoints always survive. Iterative (stack-based) so
    /// pathological inputs cannot blow the call stack.
    public static func simplify(_ coordinates: [Coordinate], tolerance: Double) -> [Coordinate] {
        guard coordinates.count > 2, tolerance > 0 else { return coordinates }
        var keep = [Bool](repeating: false, count: coordinates.count)
        keep[0] = true
        keep[coordinates.count - 1] = true

        var stack: [(start: Int, end: Int)] = [(0, coordinates.count - 1)]
        while let segment = stack.popLast() {
            guard segment.end - segment.start > 1 else { continue }
            var maxDistance = 0.0
            var maxIndex = segment.start
            for index in (segment.start + 1)..<segment.end {
                let distance = perpendicularDistance(
                    of: coordinates[index],
                    fromSegment: coordinates[segment.start],
                    to: coordinates[segment.end]
                )
                if distance > maxDistance {
                    maxDistance = distance
                    maxIndex = index
                }
            }
            if maxDistance > tolerance {
                keep[maxIndex] = true
                stack.append((segment.start, maxIndex))
                stack.append((maxIndex, segment.end))
            }
        }
        return coordinates.enumerated().compactMap { keep[$0.offset] ? $0.element : nil }
    }

    /// Distance in meters from `point` to the segment `a`→`b`, in a flat plane
    /// centered on the point (same projection the snapper uses).
    static func perpendicularDistance(of point: Coordinate, fromSegment a: Coordinate, to b: Coordinate) -> Double {
        let pa = GeoMath.planarOffset(of: a, from: point)
        let pb = GeoMath.planarOffset(of: b, from: point)
        let dx = pb.x - pa.x
        let dy = pb.y - pa.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else {
            return (pa.x * pa.x + pa.y * pa.y).squareRoot()
        }
        let t = max(0, min(1, (-pa.x * dx - pa.y * dy) / lengthSquared))
        let sx = pa.x + t * dx
        let sy = pa.y + t * dy
        return (sx * sx + sy * sy).squareRoot()
    }
}
