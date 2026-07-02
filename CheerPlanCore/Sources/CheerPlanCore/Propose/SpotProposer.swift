import Foundation

/// Auto-propose — v1's killer convenience feature. Suggests up to N viewing spots
/// given the spectator's start location and travel mode, guaranteeing every leg is
/// feasible. Works for one runner or several (shared spots must see everyone).
public struct SpotProposer: Sendable {
    public struct Request: Sendable {
        /// One or more runners on the same course.
        public var plans: [RunnerPlan]
        public var spectatorStart: Coordinate
        /// When the spectator can leave their start location. Default: the race start.
        public var earliestDeparture: Date?
        public var travelMode: TravelMode
        public var desiredCount: Int
        /// Minimum runner-distance between consecutive spots — keeps sightings meaningful.
        public var minSpacing: Double

        public init(
            plans: [RunnerPlan],
            spectatorStart: Coordinate,
            earliestDeparture: Date? = nil,
            travelMode: TravelMode = .walk,
            desiredCount: Int = 4,
            minSpacing: Double = 1000
        ) {
            self.plans = plans
            self.spectatorStart = spectatorStart
            self.earliestDeparture = earliestDeparture
            self.travelMode = travelMode
            self.desiredCount = desiredCount
            self.minSpacing = minSpacing
        }

        public init(
            plan: RunnerPlan,
            spectatorStart: Coordinate,
            earliestDeparture: Date? = nil,
            travelMode: TravelMode = .walk,
            desiredCount: Int = 4,
            minSpacing: Double = 1000
        ) {
            self.init(
                plans: [plan],
                spectatorStart: spectatorStart,
                earliestDeparture: earliestDeparture,
                travelMode: travelMode,
                desiredCount: desiredCount,
                minSpacing: minSpacing
            )
        }
    }

    public var engine: FeasibilityEngine
    /// Grid spacing of candidate spots between milestones.
    public var candidateStride: Double
    /// After the earliest feasible candidate, how much further we look for a nicer one.
    public var milestoneLookahead: Double

    public init(engine: FeasibilityEngine, candidateStride: Double = 500, milestoneLookahead: Double = 1500) {
        self.engine = engine
        self.candidateStride = candidateStride
        self.milestoneLookahead = milestoneLookahead
    }

    /// Greedy earliest-feasible walk down the course: taking the soonest reachable
    /// sighting each time leaves maximal slack for the ones after, which maximizes the
    /// total count. Within a short lookahead of the earliest OK candidate we prefer an
    /// iconic milestone (then the larger buffer), so plans read "see them at halfway",
    /// not "see them at km 19.5".
    public func propose(_ request: Request) async throws -> SupporterItinerary {
        guard let plan = request.plans.first, request.desiredCount > 0 else {
            return SupporterItinerary()
        }
        let geometry = CourseGeometry(course: plan.course)
        let schedules = FeasibilityEngine.schedules(for: request.plans)
        let candidates = candidateDistances(for: plan.course)

        var spots: [PlannedSpot] = []
        var legs: [TravelLeg] = []
        var origin = LegOrigin.start(request.spectatorStart)
        var availableFrom = request.earliestDeparture ?? FeasibilityEngine.earliestStart(of: request.plans)
        var minimumDistance = 0.0

        while spots.count < request.desiredCount {
            guard let pick = try await bestCandidate(
                from: candidates,
                atLeast: minimumDistance,
                origin: origin,
                availableFrom: availableFrom,
                mode: request.travelMode,
                schedules: schedules,
                geometry: geometry
            ) else {
                break
            }
            spots.append(pick.spot)
            legs.append(pick.leg)
            origin = .spot(pick.spot.meetPoint)
            let distance = pick.spot.meetPoint.courseDistance
            availableFrom = FeasibilityEngine.lastArrival(atDistance: distance, schedules: schedules)
                .addingTimeInterval(engine.dwell)
            minimumDistance = distance + request.minSpacing
        }
        return SupporterItinerary(spots: spots, legs: legs)
    }

    // MARK: - Candidates

    struct Candidate {
        var distance: Double
        var milestone: Milestone?
    }

    struct Pick {
        var spot: PlannedSpot
        var leg: TravelLeg
    }

    /// Milestones plus a regular grid, deduped and sorted by course distance.
    func candidateDistances(for course: Course) -> [Candidate] {
        let milestones = MilestoneGenerator.milestones(for: course.totalDistance)
        var candidates = milestones.map { Candidate(distance: $0.distance, milestone: $0) }
        var gridDistance = candidateStride
        while gridDistance < course.totalDistance {
            let nearMilestone = milestones.contains { abs($0.distance - gridDistance) < candidateStride / 2 }
            if !nearMilestone {
                candidates.append(Candidate(distance: gridDistance, milestone: nil))
            }
            gridDistance += candidateStride
        }
        return candidates.sorted { $0.distance < $1.distance }
    }

    /// Finds the earliest OK candidate past `atLeast`, then lets a nicer candidate
    /// (iconic milestone, bigger buffer) win within `milestoneLookahead` of it.
    /// Falls back to the earliest Tight candidate when nothing is OK.
    private func bestCandidate(
        from candidates: [Candidate],
        atLeast minimumDistance: Double,
        origin: LegOrigin,
        availableFrom: Date,
        mode: TravelMode,
        schedules: [FeasibilityEngine.Schedule],
        geometry: CourseGeometry
    ) async throws -> Pick? {
        var fallback: Pick?
        var window: [(pick: Pick, score: Double)] = []
        var windowEnd: Double?

        for candidate in candidates where candidate.distance >= minimumDistance {
            if let end = windowEnd, candidate.distance > end { break }

            let meetPoint = geometry.meetPoint(atDistance: candidate.distance, name: candidate.milestone?.label ?? "")
            let spot = PlannedSpot(meetPoint: meetPoint, travelMode: mode)
            let leg = try await engine.evaluateLeg(
                origin: origin,
                availableFrom: availableFrom,
                to: spot,
                deadline: FeasibilityEngine.firstArrival(atDistance: candidate.distance, schedules: schedules)
            )
            let pick = Pick(spot: spot, leg: leg)

            switch leg.verdict.status {
            case .ok:
                if windowEnd == nil {
                    windowEnd = candidate.distance + milestoneLookahead
                }
                window.append((pick, score(for: candidate, leg: leg)))
            case .tight:
                if fallback == nil {
                    fallback = pick
                }
            case .notFeasible:
                continue
            }
        }
        if let best = window.max(by: { $0.score < $1.score }) {
            return best.pick
        }
        return fallback
    }

    /// Iconic milestones beat plain markers beat anonymous grid points;
    /// buffer breaks ties (an hour of spare time ≈ one bonus point).
    private func score(for candidate: Candidate, leg: TravelLeg) -> Double {
        var score = leg.verdict.buffer / 3600
        guard let milestone = candidate.milestone else { return score }
        if case .finish = milestone.kind {
            score += 3
        } else if milestone.isIconic {
            score += 2
        } else {
            score += 0.5
        }
        return score
    }
}
