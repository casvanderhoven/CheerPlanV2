import Foundation

/// The async seam between the engine and real-world routing.
///
/// The app layer provides a MapKit-backed implementation (walk/drive/cycle/transit);
/// `HeuristicTravelEstimator` below is the built-in offline fallback.
public protocol TravelTimeProvider: Sendable {
    func travelEstimate(
        from origin: Coordinate,
        to destination: Coordinate,
        mode: TravelMode,
        departure: Date
    ) async throws -> TravelEstimate
}

/// Offline fallback: straight-line distance × mode path multiplier at the mode's
/// average speed, plus a fixed startup overhead. Always tagged `isEstimate` so the
/// UI can label it — real routing is the default, this is the escape hatch.
public struct HeuristicTravelEstimator: TravelTimeProvider {
    public init() {}

    public func travelEstimate(
        from origin: Coordinate,
        to destination: Coordinate,
        mode: TravelMode,
        departure: Date
    ) async throws -> TravelEstimate {
        let straightLine = GeoMath.distance(origin, destination)
        let routeDistance = straightLine * mode.pathMultiplier
        var duration = routeDistance / mode.heuristicSpeed
        if straightLine > 0 {
            duration += mode.fixedOverhead
        }
        return TravelEstimate(mode: mode, duration: duration, distance: routeDistance, isEstimate: true)
    }
}
