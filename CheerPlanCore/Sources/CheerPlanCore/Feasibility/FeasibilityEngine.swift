import Foundation

/// The product's core value: for every leg it compares the spectator's travel time
/// against the runner's time between the same course points and issues a verdict.
///
/// Works for one runner or several: with multiple plans (same course), the spectator
/// must arrive before the *first* runner reaches a spot and only leaves after the
/// *last* one passes.
public struct FeasibilityEngine: Sendable {
    public var provider: any TravelTimeProvider
    /// How long the spectator lingers at a spot after the (last) runner passes.
    public var dwell: TimeInterval

    public init(provider: any TravelTimeProvider, dwell: TimeInterval = 0) {
        self.provider = provider
        self.dwell = dwell
    }

    /// Thresholds scale with the leg: a fixed 2-minute buffer is wrong.
    /// Required = max(2 min, 10% of travel time) + mode arrival buffer (e.g. parking).
    public static func requiredBuffer(travelDuration: TimeInterval, mode: TravelMode) -> TimeInterval {
        max(120, 0.10 * travelDuration) + mode.arrivalBuffer
    }

    /// Evaluates an ordered spot list into a fully timed, verdict-carrying itinerary.
    /// Spots are sorted by course distance; the first leg departs from the spectator's
    /// start location at `earliestDeparture` (default: the race start).
    public func evaluate(
        spots: [PlannedSpot],
        plans: [RunnerPlan],
        spectatorStart: Coordinate,
        earliestDeparture: Date? = nil
    ) async throws -> SupporterItinerary {
        let ordered = spots.sorted { $0.meetPoint.courseDistance < $1.meetPoint.courseDistance }
        guard !plans.isEmpty else {
            return SupporterItinerary(spots: ordered, legs: [])
        }
        let schedules = Self.schedules(for: plans)
        var legs: [TravelLeg] = []
        var origin = LegOrigin.start(spectatorStart)
        var availableFrom = earliestDeparture ?? Self.earliestStart(of: plans)

        for spot in ordered {
            let distance = spot.meetPoint.courseDistance
            let leg = try await evaluateLeg(
                origin: origin,
                availableFrom: availableFrom,
                to: spot,
                deadline: Self.firstArrival(atDistance: distance, schedules: schedules)
            )
            legs.append(leg)
            origin = .spot(spot.meetPoint)
            availableFrom = Self.lastArrival(atDistance: distance, schedules: schedules)
                .addingTimeInterval(dwell)
        }
        return SupporterItinerary(spots: ordered, legs: legs)
    }

    /// Single-runner convenience.
    public func evaluate(
        spots: [PlannedSpot],
        plan: RunnerPlan,
        spectatorStart: Coordinate,
        earliestDeparture: Date? = nil
    ) async throws -> SupporterItinerary {
        try await evaluate(
            spots: spots,
            plans: [plan],
            spectatorStart: spectatorStart,
            earliestDeparture: earliestDeparture
        )
    }

    /// Core leg evaluation, shared with the fix suggester and the spot proposer:
    /// `deadline` is when the (first) runner reaches the destination.
    public func evaluateLeg(
        origin: LegOrigin,
        availableFrom: Date,
        to spot: PlannedSpot,
        deadline: Date
    ) async throws -> TravelLeg {
        let estimate = try await provider.travelEstimate(
            from: origin.coordinate,
            to: spot.meetPoint.coordinate,
            mode: spot.travelMode,
            departure: availableFrom
        )
        let spectatorArrival = availableFrom.addingTimeInterval(estimate.duration)
        let buffer = deadline.timeIntervalSince(spectatorArrival)
        let required = Self.requiredBuffer(travelDuration: estimate.duration, mode: spot.travelMode)
        let status: FeasibilityStatus
        if buffer >= required {
            status = .ok
        } else if buffer >= 0 {
            status = .tight
        } else {
            status = .notFeasible
        }
        return TravelLeg(
            origin: origin,
            destination: spot.meetPoint,
            estimate: estimate,
            departureTime: availableFrom,
            spectatorArrival: spectatorArrival,
            runnerArrival: deadline,
            latestDeparture: deadline.addingTimeInterval(-estimate.duration),
            verdict: FeasibilityVerdict(status: status, buffer: buffer, requiredBuffer: required)
        )
    }

    // MARK: - Runner schedules

    /// Precomputed (start, pace model) pairs so evaluation loops don't rebuild models.
    typealias Schedule = (start: Date, model: PaceModel)

    static func schedules(for plans: [RunnerPlan]) -> [Schedule] {
        plans.map { ($0.startTime, $0.paceModel()) }
    }

    static func earliestStart(of plans: [RunnerPlan]) -> Date {
        plans.map(\.startTime).min() ?? Date.distantPast
    }

    static func firstArrival(atDistance distance: Double, schedules: [Schedule]) -> Date {
        schedules
            .map { $0.start.addingTimeInterval($0.model.time(atDistance: distance)) }
            .min() ?? Date.distantFuture
    }

    static func lastArrival(atDistance distance: Double, schedules: [Schedule]) -> Date {
        schedules
            .map { $0.start.addingTimeInterval($0.model.time(atDistance: distance)) }
            .max() ?? Date.distantPast
    }

    /// When the first of the given runners reaches `distance`.
    public static func firstArrival(atDistance distance: Double, plans: [RunnerPlan]) -> Date {
        firstArrival(atDistance: distance, schedules: schedules(for: plans))
    }

    /// When the last of the given runners reaches `distance`.
    public static func lastArrival(atDistance distance: Double, plans: [RunnerPlan]) -> Date {
        lastArrival(atDistance: distance, schedules: schedules(for: plans))
    }
}
