import Foundation

/// The single ETA model every position source funnels into.
///
/// Observations are anchored at the most recent one; the planned schedule between
/// any two course points is scaled by the observed pace ratio, so every projected
/// arrival adapts when the runner is ahead of or behind plan. With no observations
/// it degrades gracefully to the planned schedule.
public struct ProgressEstimator: Sendable {
    public let plan: RunnerPlan
    private let model: PaceModel
    public private(set) var observations: [RunnerObservation]

    public init(plan: RunnerPlan, observations: [RunnerObservation] = []) {
        self.plan = plan
        self.model = plan.paceModel()
        self.observations = observations.sorted { $0.timestamp < $1.timestamp }
    }

    public mutating func record(_ observation: RunnerObservation) {
        observations.append(observation)
        observations.sort { $0.timestamp < $1.timestamp }
    }

    public var latest: RunnerObservation? {
        observations.last
    }

    /// Observed pace relative to plan: 1 on plan, above 1 slower, below 1 faster.
    ///
    /// Blends the whole-race ratio with the ratio over the two most recent
    /// observations, weighted toward recent form (0.7/0.3), clamped to [0.3, 3].
    /// Very early observations (under a minute of planned running) are ignored —
    /// there is no signal in them.
    public var paceRatio: Double {
        guard let latest else { return 1 }
        let plannedElapsed = model.time(atDistance: latest.courseDistance)
        let actualElapsed = latest.timestamp.timeIntervalSince(plan.startTime)
        guard plannedElapsed >= 60, actualElapsed > 0 else { return 1 }
        let cumulative = actualElapsed / plannedElapsed

        var ratio = cumulative
        if observations.count >= 2 {
            let previous = observations[observations.count - 2]
            let plannedSegment = plannedElapsed - model.time(atDistance: previous.courseDistance)
            let actualSegment = latest.timestamp.timeIntervalSince(previous.timestamp)
            if plannedSegment >= 30, actualSegment > 0 {
                ratio = 0.7 * (actualSegment / plannedSegment) + 0.3 * cumulative
            }
        }
        return min(3, max(0.3, ratio))
    }

    /// Projected arrival at `distance` meters, anchored at the latest observation.
    public func projectedArrival(atDistance distance: Double) -> Date {
        guard let latest else {
            return plan.arrivalTime(atDistance: distance)
        }
        let plannedDelta = model.time(atDistance: distance) - model.time(atDistance: latest.courseDistance)
        return latest.timestamp.addingTimeInterval(plannedDelta * paceRatio)
    }

    /// Estimated runner position at `date`.
    public func estimatedDistance(at date: Date) -> Double {
        guard let latest else {
            return model.distance(atTime: date.timeIntervalSince(plan.startTime))
        }
        let plannedAnchor = model.time(atDistance: latest.courseDistance)
        let scaledElapsed = date.timeIntervalSince(latest.timestamp) / paceRatio
        return model.distance(atTime: plannedAnchor + scaledElapsed)
    }

    /// Seconds behind plan (positive) or ahead of it (negative) at the latest observation.
    public var scheduleDelta: TimeInterval {
        guard let latest else { return 0 }
        return latest.timestamp.timeIntervalSince(plan.startTime) - model.time(atDistance: latest.courseDistance)
    }

    public var projectedFinish: Date {
        projectedArrival(atDistance: model.courseDistance)
    }
}
