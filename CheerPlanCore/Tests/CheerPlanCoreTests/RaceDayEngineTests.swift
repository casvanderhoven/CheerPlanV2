import Foundation
import Testing
@testable import CheerPlanCore

@Suite struct RaceDayEngineTests {
    /// 10 km straight course, runner at 5:00/km, spectator starting 100 m before
    /// km 2. Spots: km 2 on foot (travel ≈ 96 s), km 6 by car (travel ≈ 843 s).
    func raceSetup() async throws -> (plan: RunnerPlan, itinerary: SupporterItinerary) {
        let course = try straightNorthCourse()
        let geometry = CourseGeometry(course: course)
        let plan = steadyPlan(course: course, secondsPerKilometer: 300)
        let engine = FeasibilityEngine(provider: HeuristicTravelEstimator())
        let itinerary = try await engine.evaluate(
            spots: [
                PlannedSpot(meetPoint: geometry.meetPoint(atDistance: 2_000), travelMode: .walk),
                PlannedSpot(meetPoint: geometry.meetPoint(atDistance: 6_000), travelMode: .drive)
            ],
            plan: plan,
            spectatorStart: geometry.point(atDistance: 1_900).coordinate
        )
        return (plan, itinerary)
    }

    func elapsed(_ seconds: TimeInterval) -> Date {
        raceStart.addingTimeInterval(seconds)
    }

    @Test func quietMorningIsBeforeStart() async throws {
        let (plan, itinerary) = try await raceSetup()
        let estimator = ProgressEstimator(plan: plan)
        let snapshot = RaceDayEngine.snapshot(itinerary: itinerary, estimator: estimator, at: elapsed(-600))
        #expect(snapshot.phase == .beforeStart)
        #expect(snapshot.leaveBy != nil)
        #expect(snapshot.passedLegIndexes.isEmpty)
        #expect(snapshot.runnerCourseDistance == 0)
    }

    @Test func comfortablyEarlyMeansStay() async throws {
        let (plan, itinerary) = try await raceSetup()
        let estimator = ProgressEstimator(plan: plan)
        let snapshot = RaceDayEngine.snapshot(itinerary: itinerary, estimator: estimator, at: elapsed(100))
        #expect(snapshot.phase == .stay(nextLegIndex: 0))
        // leaveBy = arrival(600) − travel(96.3) − required(120)
        let leaveBy = try #require(snapshot.leaveBy)
        #expect(approx(leaveBy, elapsed(600 - 96.3 - 120), tolerance: 2))
        let lastChance = try #require(snapshot.lastChance)
        #expect(approx(lastChance, elapsed(600 - 96.3), tolerance: 2))
    }

    @Test func pastLeaveByMeansGo() async throws {
        let (plan, itinerary) = try await raceSetup()
        let estimator = ProgressEstimator(plan: plan)
        let snapshot = RaceDayEngine.snapshot(itinerary: itinerary, estimator: estimator, at: elapsed(450))
        #expect(snapshot.phase == .go(nextLegIndex: 0))
    }

    @Test func passedSpotAdvancesToTheNextLeg() async throws {
        let (plan, itinerary) = try await raceSetup()
        let estimator = ProgressEstimator(plan: plan)
        let snapshot = RaceDayEngine.snapshot(itinerary: itinerary, estimator: estimator, at: elapsed(700))
        // Runner passed km 2 at 600 s; the drive to km 6 (843 s travel + 420 s
        // buffer against an 1800 s arrival) means leaving immediately.
        #expect(snapshot.passedLegIndexes == [0])
        #expect(snapshot.phase == .go(nextLegIndex: 1))
        let leaveBy = try #require(snapshot.leaveBy)
        #expect(approx(leaveBy, elapsed(1_800 - 843.1 - 420.3), tolerance: 3))
        #expect(approx(snapshot.runnerCourseDistance, 2_333, tolerance: 5))
    }

    @Test func behindPlanObservationPushesLeaveByLater() async throws {
        let (plan, itinerary) = try await raceSetup()
        var estimator = ProgressEstimator(plan: plan)
        // Runner hits km 2 a minute late → 10% slow.
        estimator.record(RunnerObservation(courseDistance: 2_000, timestamp: elapsed(660), source: .checkIn))
        let snapshot = RaceDayEngine.snapshot(itinerary: itinerary, estimator: estimator, at: elapsed(700))

        #expect(approx(snapshot.scheduleDelta, 60, tolerance: 1))
        // projected arrival at km 6: 660 + 1200 × 1.1 = 1980
        #expect(approx(snapshot.projectedArrivals[1], elapsed(1_980), tolerance: 2))
        let leaveBy = try #require(snapshot.leaveBy)
        #expect(approx(leaveBy, elapsed(1_980 - 843.1 - 420.3), tolerance: 3))
        // the extra minute turns "go" back into "stay"
        #expect(snapshot.phase == .stay(nextLegIndex: 1))
    }

    @Test func everythingPassedIsFinished() async throws {
        let (plan, itinerary) = try await raceSetup()
        let estimator = ProgressEstimator(plan: plan)
        let snapshot = RaceDayEngine.snapshot(itinerary: itinerary, estimator: estimator, at: elapsed(5_000))
        #expect(snapshot.phase == .finished)
        #expect(snapshot.passedLegIndexes == [0, 1])
        #expect(snapshot.leaveBy == nil)
    }

    @Test func emptyItineraryFinishesAfterTheGun() async throws {
        let (plan, _) = try await raceSetup()
        let estimator = ProgressEstimator(plan: plan)
        let empty = SupporterItinerary()
        #expect(RaceDayEngine.snapshot(itinerary: empty, estimator: estimator, at: elapsed(-100)).phase == .beforeStart)
        #expect(RaceDayEngine.snapshot(itinerary: empty, estimator: estimator, at: elapsed(100)).phase == .finished)
    }
}

@Suite struct BearingTests {
    @Test func cardinalBearings() {
        let base = Coordinate(latitude: 52.0, longitude: 4.0)
        let north = Coordinate(latitude: 52.01, longitude: 4.0)
        let east = Coordinate(latitude: 52.0, longitude: 4.01)
        #expect(approx(base.bearing(toward: north), 0, tolerance: 0.1))
        #expect(approx(base.bearing(toward: east), 90, tolerance: 0.1))
        #expect(approx(north.bearing(toward: base), 180, tolerance: 0.1))
        #expect(approx(east.bearing(toward: base), 270, tolerance: 0.1))
    }

    @Test func compassLabels() {
        #expect(Formatters.compass(bearing: 0) == "N")
        #expect(Formatters.compass(bearing: 44) == "NE")
        #expect(Formatters.compass(bearing: 90) == "E")
        #expect(Formatters.compass(bearing: 200) == "S")
        #expect(Formatters.compass(bearing: 210) == "SW")
        #expect(Formatters.compass(bearing: 337.6) == "N")
        #expect(Formatters.compass(bearing: -45) == "NW")
        #expect(Formatters.compass(bearing: 720 + 45) == "NE")
    }
}

@Suite struct DocumentCompatibilityTests {
    /// Documents written before M6 lack the new optional keys — they must decode.
    @Test func preM6SupporterPlanDecodes() throws {
        let json = """
        {"id":"11111111-1111-1111-1111-111111111111",
         "runnerPlanID":"22222222-2222-2222-2222-222222222222",
         "spots":[]}
        """
        let plan = try JSONDecoder().decode(SupporterPlan.self, from: Data(json.utf8))
        #expect(plan.additionalRunnerPlanIDs == nil)
        #expect(plan.allRunnerPlanIDs.count == 1)
    }

    @Test func preM6PlannedSpotDecodes() throws {
        let json = """
        {"meetPoint":{"id":"33333333-3333-3333-3333-333333333333","name":"",
          "coordinate":{"latitude":52.0,"longitude":4.0},"courseDistance":1000},
         "travelMode":"walk"}
        """
        let spot = try JSONDecoder().decode(PlannedSpot.self, from: Data(json.utf8))
        #expect(spot.assignee == nil)
        #expect(spot.travelMode == .walk)
    }

    @Test func raceSessionRoundTrips() throws {
        let session = RaceSession(
            supporterPlanID: UUID(),
            runnerPlanID: UUID(),
            startedAt: raceStart,
            observations: [RunnerObservation(courseDistance: 5_000, timestamp: raceStart, source: .checkIn)]
        )
        let decoded = try JSONDecoder().decode(RaceSession.self, from: JSONEncoder().encode(session))
        #expect(decoded == session)
    }
}
