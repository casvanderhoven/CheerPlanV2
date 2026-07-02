import CheerPlanCore
import Foundation

/// The live race engine — an actor owning the timing model (spec §5), with a
/// persisted event log of observations so state reconstructs exactly after the
/// app is killed: `startOrResume` replays the log into a fresh estimator.
public actor LiveRaceEngine {
    public let runnerPlan: RunnerPlan
    public let itinerary: SupporterItinerary
    private let store: any RaceSessionStore
    private var session: RaceSession
    private var estimator: ProgressEstimator

    public init(
        session: RaceSession,
        runnerPlan: RunnerPlan,
        itinerary: SupporterItinerary,
        store: any RaceSessionStore
    ) {
        self.session = session
        self.runnerPlan = runnerPlan
        self.itinerary = itinerary
        self.store = store
        self.estimator = ProgressEstimator(plan: runnerPlan, observations: session.observations)
    }

    /// Resumes the active session for this supporter plan, or starts (and
    /// immediately persists) a new one.
    public static func startOrResume(
        supporterPlan: SupporterPlan,
        runnerPlan: RunnerPlan,
        itinerary: SupporterItinerary,
        store: any RaceSessionStore,
        startedAt: Date = Date()
    ) async throws -> LiveRaceEngine {
        if let existing = try await store.fetchActive(supporterPlanID: supporterPlan.id) {
            return LiveRaceEngine(session: existing, runnerPlan: runnerPlan, itinerary: itinerary, store: store)
        }
        let session = RaceSession(
            supporterPlanID: supporterPlan.id,
            runnerPlanID: runnerPlan.id,
            startedAt: startedAt
        )
        try await store.save(session)
        return LiveRaceEngine(session: session, runnerPlan: runnerPlan, itinerary: itinerary, store: store)
    }

    public var currentSession: RaceSession {
        session
    }

    /// Appends to the event log — committed to the store before this returns,
    /// so a force quit right after a check-in loses nothing.
    public func record(_ observation: RunnerObservation) async throws {
        session.observations.append(observation)
        session.observations.sort { $0.timestamp < $1.timestamp }
        estimator = ProgressEstimator(plan: runnerPlan, observations: session.observations)
        try await store.save(session)
    }

    public func snapshot(at now: Date) -> RaceSnapshot {
        RaceDayEngine.snapshot(itinerary: itinerary, estimator: estimator, at: now)
    }

    public func end() async throws {
        session.isEnded = true
        try await store.save(session)
    }
}
