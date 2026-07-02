import Foundation

/// One concrete way to repair an infeasible leg.
public enum FixSuggestion: Hashable, Sendable {
    /// Switch how the spectator travels this leg (driving included — v1 forgot it).
    case changeTravelMode(to: TravelMode, verdict: FeasibilityVerdict)
    /// Move the destination spot forward to the nearest feasible course distance.
    case moveDestination(to: MeetPoint, verdict: FeasibilityVerdict)
    case removeDestinationSpot(MeetPoint)
    case removeSourceSpot(MeetPoint)
}

/// Never dead-end the user: every Not Feasible leg gets multi-option fixes.
public struct FixSuggester: Sendable {
    public var engine: FeasibilityEngine
    /// Granularity of the move-the-spot search along the course.
    public var searchStep: Double
    /// How far forward the move-the-spot search is willing to go.
    public var maxSearchDistance: Double

    public init(engine: FeasibilityEngine, searchStep: Double = 250, maxSearchDistance: Double = 8000) {
        self.engine = engine
        self.searchStep = searchStep
        self.maxSearchDistance = maxSearchDistance
    }

    /// Fixes for the leg at `index` of an evaluated itinerary. Empty unless the leg
    /// is Not Feasible. Ordered most-attractive-first: mode changes (plan unchanged),
    /// then moving the spot, then dropping spots.
    public func suggestions(
        forLegAt index: Int,
        in itinerary: SupporterItinerary,
        plans: [RunnerPlan],
        geometry: CourseGeometry
    ) async throws -> [FixSuggestion] {
        guard itinerary.legs.indices.contains(index),
              itinerary.spots.indices.contains(index) else {
            return []
        }
        let leg = itinerary.legs[index]
        guard leg.verdict.status == .notFeasible else { return [] }
        let spot = itinerary.spots[index]

        var suggestions: [FixSuggestion] = []
        suggestions += try await modeChanges(for: leg, spot: spot)
        let move = try await movedDestination(
            for: leg,
            spot: spot,
            at: index,
            in: itinerary,
            plans: plans,
            geometry: geometry
        )
        if let move {
            suggestions.append(move)
        }
        suggestions.append(.removeDestinationSpot(spot.meetPoint))
        if let source = leg.origin.meetPoint {
            suggestions.append(.removeSourceSpot(source))
        }
        return suggestions
    }

    /// Every other travel mode that makes the leg feasible, best buffer first.
    private func modeChanges(for leg: TravelLeg, spot: PlannedSpot) async throws -> [FixSuggestion] {
        var feasible: [(mode: TravelMode, verdict: FeasibilityVerdict)] = []
        for mode in TravelMode.allCases where mode != spot.travelMode {
            let candidate = PlannedSpot(meetPoint: spot.meetPoint, travelMode: mode)
            let evaluated = try await engine.evaluateLeg(
                origin: leg.origin,
                availableFrom: leg.departureTime,
                to: candidate,
                deadline: leg.runnerArrival
            )
            if evaluated.verdict.status != .notFeasible {
                feasible.append((mode, evaluated.verdict))
            }
        }
        return feasible
            .sorted { $0.verdict.buffer > $1.verdict.buffer }
            .map { .changeTravelMode(to: $0.mode, verdict: $0.verdict) }
    }

    /// The nearest course distance further along where this leg becomes feasible,
    /// without overtaking the next planned spot.
    private func movedDestination(
        for leg: TravelLeg,
        spot: PlannedSpot,
        at index: Int,
        in itinerary: SupporterItinerary,
        plans: [RunnerPlan],
        geometry: CourseGeometry
    ) async throws -> FixSuggestion? {
        let schedules = FeasibilityEngine.schedules(for: plans)
        let nextSpotDistance = itinerary.spots.indices.contains(index + 1)
            ? itinerary.spots[index + 1].meetPoint.courseDistance
            : geometry.course.totalDistance
        let limit = min(spot.meetPoint.courseDistance + maxSearchDistance, nextSpotDistance)

        var distance = spot.meetPoint.courseDistance + searchStep
        while distance <= limit {
            let moved = geometry.meetPoint(atDistance: distance, name: spot.meetPoint.name)
            let evaluated = try await engine.evaluateLeg(
                origin: leg.origin,
                availableFrom: leg.departureTime,
                to: PlannedSpot(meetPoint: moved, travelMode: spot.travelMode),
                deadline: FeasibilityEngine.firstArrival(atDistance: distance, schedules: schedules)
            )
            if evaluated.verdict.status != .notFeasible {
                return .moveDestination(to: moved, verdict: evaluated.verdict)
            }
            distance += searchStep
        }
        return nil
    }
}
