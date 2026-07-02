import CheerPlanCore
import Foundation
import MapKit

/// Real routing (spec §5): MKDirections routes for walking and driving, the ETA
/// API for transit. MapKit exposes no cycling ETAs, so cycling uses the heuristic
/// and stays tagged `isEstimate`. Wrapped in `FallbackTravelTimeProvider` and
/// `CachedTravelTimeProvider` by `Dependencies.live()` for offline resilience.
struct MapKitTravelTimeProvider: TravelTimeProvider {
    private let heuristic = HeuristicTravelEstimator()

    func travelEstimate(
        from origin: Coordinate,
        to destination: Coordinate,
        mode: TravelMode,
        departure: Date
    ) async throws -> TravelEstimate {
        switch mode {
        case .cycle:
            return try await heuristic.travelEstimate(from: origin, to: destination, mode: mode, departure: departure)
        case .transit:
            let request = request(from: origin, to: destination, transport: .transit, departure: departure)
            let response = try await MKDirections(request: request).calculateETA()
            return TravelEstimate(
                mode: mode,
                duration: response.expectedTravelTime,
                distance: response.distance,
                isEstimate: false
            )
        case .walk:
            return try await route(from: origin, to: destination, transport: .walking, mode: mode, departure: departure)
        case .drive:
            return try await route(from: origin, to: destination, transport: .automobile, mode: mode, departure: departure)
        }
    }

    private func route(
        from origin: Coordinate,
        to destination: Coordinate,
        transport: MKDirectionsTransportType,
        mode: TravelMode,
        departure: Date
    ) async throws -> TravelEstimate {
        let request = request(from: origin, to: destination, transport: transport, departure: departure)
        let response = try await MKDirections(request: request).calculate()
        guard let fastest = response.routes.min(by: { $0.expectedTravelTime < $1.expectedTravelTime }) else {
            return try await heuristic.travelEstimate(from: origin, to: destination, mode: mode, departure: departure)
        }
        return TravelEstimate(mode: mode, duration: fastest.expectedTravelTime, distance: fastest.distance, isEstimate: false)
    }

    private func request(
        from origin: Coordinate,
        to destination: Coordinate,
        transport: MKDirectionsTransportType,
        departure: Date
    ) -> MKDirections.Request {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: mapCoordinate(origin)))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: mapCoordinate(destination)))
        request.transportType = transport
        request.departureDate = departure
        return request
    }
}
