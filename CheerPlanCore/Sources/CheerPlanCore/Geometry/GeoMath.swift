import Foundation

/// Pure geographic math on a spherical Earth model.
enum GeoMath {
    static let earthRadius = 6_371_000.0

    /// Great-circle distance in meters (haversine).
    static func distance(_ a: Coordinate, _ b: Coordinate) -> Double {
        let lat1 = a.latitude * .pi / 180
        let lat2 = b.latitude * .pi / 180
        let deltaLat = (b.latitude - a.latitude) * .pi / 180
        let deltaLon = (b.longitude - a.longitude) * .pi / 180
        let h = sin(deltaLat / 2) * sin(deltaLat / 2)
            + cos(lat1) * cos(lat2) * sin(deltaLon / 2) * sin(deltaLon / 2)
        return 2 * earthRadius * asin(min(1, sqrt(h)))
    }

    /// Projects `point` into a flat plane centered on `origin` (equirectangular),
    /// returning (x: east, y: north) in meters. Accurate at spot-picking scales.
    static func planarOffset(of point: Coordinate, from origin: Coordinate) -> (x: Double, y: Double) {
        let meanLatitude = (point.latitude + origin.latitude) / 2 * .pi / 180
        let x = (point.longitude - origin.longitude) * .pi / 180 * cos(meanLatitude) * earthRadius
        let y = (point.latitude - origin.latitude) * .pi / 180 * earthRadius
        return (x, y)
    }

    /// Linear interpolation between two coordinates (valid at track-segment scales).
    static func interpolate(_ a: Coordinate, _ b: Coordinate, fraction: Double) -> Coordinate {
        Coordinate(
            latitude: a.latitude + (b.latitude - a.latitude) * fraction,
            longitude: a.longitude + (b.longitude - a.longitude) * fraction
        )
    }
}
