import Foundation

/// A meet point plus the travel mode used to reach it — the itinerary building block.
public struct PlannedSpot: Identifiable, Equatable, Codable, Sendable {
    public var meetPoint: MeetPoint
    /// Mode used to travel *to* this spot (per-leg travel mode).
    public var travelMode: TravelMode
    /// Which crew member covers this spot (M6). Local label; optional so
    /// documents written before M6 keep decoding.
    public var assignee: String?

    public var id: UUID { meetPoint.id }

    public init(meetPoint: MeetPoint, travelMode: TravelMode, assignee: String? = nil) {
        self.meetPoint = meetPoint
        self.travelMode = travelMode
        self.assignee = assignee
    }
}

/// Where a travel leg starts: the spectator's own start location, or a previous spot.
public enum LegOrigin: Equatable, Codable, Sendable {
    case start(Coordinate)
    case spot(MeetPoint)

    public var coordinate: Coordinate {
        switch self {
        case .start(let coordinate): coordinate
        case .spot(let meetPoint): meetPoint.coordinate
        }
    }

    public var meetPoint: MeetPoint? {
        switch self {
        case .start: nil
        case .spot(let meetPoint): meetPoint
        }
    }
}

/// One evaluated hop of the supporter's day, with the times that make it glanceable:
/// leave at `departureTime`, no later than `latestDeparture`, runner arrives `runnerArrival`.
public struct TravelLeg: Equatable, Codable, Sendable {
    public var origin: LegOrigin
    public var destination: MeetPoint
    public var estimate: TravelEstimate
    /// Earliest the spectator can leave the origin (after the runner passes it).
    public var departureTime: Date
    public var spectatorArrival: Date
    /// When the (first) runner reaches the destination.
    public var runnerArrival: Date
    /// Leave later than this and the sighting is lost.
    public var latestDeparture: Date
    public var verdict: FeasibilityVerdict

    public init(
        origin: LegOrigin,
        destination: MeetPoint,
        estimate: TravelEstimate,
        departureTime: Date,
        spectatorArrival: Date,
        runnerArrival: Date,
        latestDeparture: Date,
        verdict: FeasibilityVerdict
    ) {
        self.origin = origin
        self.destination = destination
        self.estimate = estimate
        self.departureTime = departureTime
        self.spectatorArrival = spectatorArrival
        self.runnerArrival = runnerArrival
        self.latestDeparture = latestDeparture
        self.verdict = verdict
    }
}

/// Ordered spots plus the evaluated travel between them.
public struct SupporterItinerary: Equatable, Codable, Sendable {
    public var spots: [PlannedSpot]
    public var legs: [TravelLeg]

    public init(spots: [PlannedSpot] = [], legs: [TravelLeg] = []) {
        self.spots = spots
        self.legs = legs
    }

    /// The traffic light for the whole plan: the worst leg wins.
    public var worstStatus: FeasibilityStatus {
        legs.map(\.verdict.status).max() ?? .ok
    }

    public var sightings: Int { spots.count }
}
