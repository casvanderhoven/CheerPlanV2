import Foundation

/// What race day looks like right now: one phase, one deadline, and the
/// projections behind them. Pure output of `RaceDayEngine.snapshot`.
public struct RaceSnapshot: Equatable, Sendable {
    public enum Phase: Equatable, Sendable {
        case beforeStart
        /// Enjoy where you are — no need to move for leg `nextLegIndex` yet.
        case stay(nextLegIndex: Int)
        /// Leave now (or you're already late) for leg `nextLegIndex`.
        case go(nextLegIndex: Int)
        /// Every planned sighting is behind you.
        case finished
    }

    public var now: Date
    public var phase: Phase
    /// Estimated runner position, meters from the start.
    public var runnerCourseDistance: Double
    /// Seconds behind plan (positive) or ahead of it (negative).
    public var scheduleDelta: TimeInterval
    /// Legs whose projected runner arrival is already in the past.
    public var passedLegIndexes: [Int]
    /// Projected (recalibrated) runner arrival at every leg's spot.
    public var projectedArrivals: [Date]
    /// Comfortable departure for the next leg — includes the required buffer.
    public var leaveBy: Date?
    /// Absolute latest departure that still makes the sighting (zero buffer).
    public var lastChance: Date?

    public var nextLegIndex: Int? {
        switch phase {
        case .stay(let index), .go(let index): index
        case .beforeStart, .finished: nil
        }
    }
}

/// The pure race-day state machine. Uses the itinerary's *stored* travel
/// estimates (race day stays offline-first once the plan is loaded) and the
/// estimator's recalibrated projections for every runner time.
public enum RaceDayEngine {
    public static func snapshot(
        itinerary: SupporterItinerary,
        estimator: ProgressEstimator,
        at now: Date
    ) -> RaceSnapshot {
        let projected = itinerary.legs.map {
            estimator.projectedArrival(atDistance: $0.destination.courseDistance)
        }
        let passed = projected.enumerated().filter { $0.element <= now }.map(\.offset)
        let runnerDistance = estimator.estimatedDistance(at: now)
        let delta = estimator.scheduleDelta

        guard let nextIndex = projected.firstIndex(where: { $0 > now }) else {
            // Nothing left ahead: before the gun with no plan, or all done.
            let phase: RaceSnapshot.Phase = now < estimator.plan.startTime ? .beforeStart : .finished
            return RaceSnapshot(
                now: now,
                phase: phase,
                runnerCourseDistance: runnerDistance,
                scheduleDelta: delta,
                passedLegIndexes: passed,
                projectedArrivals: projected,
                leaveBy: nil,
                lastChance: nil
            )
        }

        let leg = itinerary.legs[nextIndex]
        let travel = leg.estimate.duration
        let required = FeasibilityEngine.requiredBuffer(travelDuration: travel, mode: leg.estimate.mode)
        let arrival = projected[nextIndex]
        let leaveBy = arrival.addingTimeInterval(-(travel + required))
        let lastChance = arrival.addingTimeInterval(-travel)

        let phase: RaceSnapshot.Phase
        if now < estimator.plan.startTime, now < leaveBy {
            phase = .beforeStart
        } else if now >= leaveBy {
            phase = .go(nextLegIndex: nextIndex)
        } else {
            phase = .stay(nextLegIndex: nextIndex)
        }

        return RaceSnapshot(
            now: now,
            phase: phase,
            runnerCourseDistance: runnerDistance,
            scheduleDelta: delta,
            passedLegIndexes: passed,
            projectedArrivals: projected,
            leaveBy: leaveBy,
            lastChance: lastChance
        )
    }
}
