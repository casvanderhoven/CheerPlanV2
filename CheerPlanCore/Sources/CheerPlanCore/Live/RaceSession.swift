import Foundation

/// One supporter's race day: a persisted event log of runner observations
/// (spec §5). Nothing else is stored — the timing model reconstructs exactly by
/// replaying `observations` into a `ProgressEstimator`, which is what makes
/// state survive force quits and phone restarts.
public struct RaceSession: Identifiable, Equatable, Codable, Sendable {
    public let id: UUID
    public var supporterPlanID: UUID
    public var runnerPlanID: UUID
    public var startedAt: Date
    public var observations: [RunnerObservation]
    public var isEnded: Bool

    public init(
        id: UUID = UUID(),
        supporterPlanID: UUID,
        runnerPlanID: UUID,
        startedAt: Date,
        observations: [RunnerObservation] = [],
        isEnded: Bool = false
    ) {
        self.id = id
        self.supporterPlanID = supporterPlanID
        self.runnerPlanID = runnerPlanID
        self.startedAt = startedAt
        self.observations = observations
        self.isEnded = isEnded
    }
}
