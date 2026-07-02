import CheerPlanCore
import Foundation
import GRDB
import Testing
@testable import CheerPlanData

@Suite struct LiveRaceEngineTests {
    let gunTime = Date(timeIntervalSince1970: 1_750_000_000)

    func setup() async throws -> (plan: RunnerPlan, supporter: SupporterPlan, itinerary: SupporterItinerary) {
        let course = try sampleCourse() // 10 × ~1 km north
        let geometry = CourseGeometry(course: course)
        let plan = RunnerPlan(name: "Runner", course: course, startTime: gunTime, pacing: .steady(secondsPerKilometer: 300))
        let spots = [
            PlannedSpot(meetPoint: geometry.meetPoint(atDistance: 2_000), travelMode: .walk),
            PlannedSpot(meetPoint: geometry.meetPoint(atDistance: 6_000), travelMode: .drive)
        ]
        let itinerary = try await FeasibilityEngine(provider: HeuristicTravelEstimator()).evaluate(
            spots: spots,
            plan: plan,
            spectatorStart: geometry.point(atDistance: 1_900).coordinate
        )
        let supporter = SupporterPlan(runnerPlanID: plan.id, spots: spots)
        return (plan, supporter, itinerary)
    }

    @Test func stateSurvivesForceQuit() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("cheerplan-race-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: url) }
        let (plan, supporter, itinerary) = try await setup()

        let checkIn = RunnerObservation(courseDistance: 2_000, timestamp: gunTime.addingTimeInterval(660), source: .checkIn)
        let recalibration = RunnerObservation(
            courseDistance: 3_000,
            timestamp: gunTime.addingTimeInterval(1_000),
            source: .recalibration
        )
        let sessionID: UUID
        let snapshotBefore: RaceSnapshot
        do {
            let store = GRDBRaceSessionStore(database: try AppDatabase(GRDB.DatabaseQueue(path: url.path)))
            let engine = try await LiveRaceEngine.startOrResume(
                supporterPlan: supporter,
                runnerPlan: plan,
                itinerary: itinerary,
                store: store,
                startedAt: gunTime
            )
            try await engine.record(checkIn)
            try await engine.record(recalibration)
            sessionID = await engine.currentSession.id
            snapshotBefore = await engine.snapshot(at: gunTime.addingTimeInterval(1_100))
        }

        // "Force quit": everything above is gone; reopen the same database file.
        let reopenedStore = GRDBRaceSessionStore(database: try AppDatabase(GRDB.DatabaseQueue(path: url.path)))
        let resumed = try await LiveRaceEngine.startOrResume(
            supporterPlan: supporter,
            runnerPlan: plan,
            itinerary: itinerary,
            store: reopenedStore,
            startedAt: gunTime.addingTimeInterval(9_999) // must be ignored — session resumes
        )
        #expect(await resumed.currentSession.id == sessionID)
        #expect(await resumed.currentSession.observations == [checkIn, recalibration])
        let snapshotAfter = await resumed.snapshot(at: gunTime.addingTimeInterval(1_100))
        #expect(snapshotAfter == snapshotBefore)
    }

    @Test func endedSessionsAreNotResumed() async throws {
        let (plan, supporter, itinerary) = try await setup()
        let store = InMemoryRaceSessionStore()
        let first = try await LiveRaceEngine.startOrResume(
            supporterPlan: supporter,
            runnerPlan: plan,
            itinerary: itinerary,
            store: store,
            startedAt: gunTime
        )
        let firstID = await first.currentSession.id
        try await first.end()
        #expect(try await store.fetchActive(supporterPlanID: supporter.id) == nil)

        let second = try await LiveRaceEngine.startOrResume(
            supporterPlan: supporter,
            runnerPlan: plan,
            itinerary: itinerary,
            store: store,
            startedAt: gunTime
        )
        #expect(await second.currentSession.id != firstID)
    }

    @Test func resumingDoesNotDuplicateSessions() async throws {
        let (plan, supporter, itinerary) = try await setup()
        let store = InMemoryRaceSessionStore()
        let first = try await LiveRaceEngine.startOrResume(
            supporterPlan: supporter, runnerPlan: plan, itinerary: itinerary, store: store, startedAt: gunTime
        )
        let second = try await LiveRaceEngine.startOrResume(
            supporterPlan: supporter, runnerPlan: plan, itinerary: itinerary, store: store, startedAt: gunTime
        )
        #expect(await first.currentSession.id == second.currentSession.id)
    }

    @Test func recordingUpdatesProjections() async throws {
        let (plan, supporter, itinerary) = try await setup()
        let engine = try await LiveRaceEngine.startOrResume(
            supporterPlan: supporter,
            runnerPlan: plan,
            itinerary: itinerary,
            store: InMemoryRaceSessionStore(),
            startedAt: gunTime
        )
        let before = await engine.snapshot(at: gunTime.addingTimeInterval(700))
        try await engine.record(
            RunnerObservation(courseDistance: 2_000, timestamp: gunTime.addingTimeInterval(660), source: .checkIn)
        )
        let after = await engine.snapshot(at: gunTime.addingTimeInterval(700))
        #expect(after.scheduleDelta > before.scheduleDelta)
        #expect(after.projectedArrivals[1] > before.projectedArrivals[1])
    }
}
