import Foundation

/// How the spectator moves between viewing spots.
public enum TravelMode: String, CaseIterable, Equatable, Codable, Sendable {
    case walk
    case cycle
    case drive
    case transit

    public var displayName: String {
        switch self {
        case .walk: "Walk"
        case .cycle: "Cycle"
        case .drive: "Drive"
        case .transit: "Transit"
        }
    }

    /// Average speed assumed by the offline heuristic estimate, m/s.
    public var heuristicSpeed: Double {
        switch self {
        case .walk: 1.35
        case .cycle: 4.2
        case .drive: 8.3
        case .transit: 5.5
        }
    }

    /// Streets are longer than the crow flies; multiplier on straight-line distance.
    public var pathMultiplier: Double {
        switch self {
        case .walk: 1.3
        case .cycle: 1.4
        case .drive: 1.5
        case .transit: 1.4
        }
    }

    /// Fixed startup cost: unlock the bike, reach the platform, get to the car.
    public var fixedOverhead: TimeInterval {
        switch self {
        case .walk: 0
        case .cycle: 60
        case .drive: 120
        case .transit: 300
        }
    }

    /// Extra safety buffer required on arrival (parking, connection risk).
    public var arrivalBuffer: TimeInterval {
        switch self {
        case .walk: 0
        case .cycle: 60
        case .drive: 300
        case .transit: 120
        }
    }
}
