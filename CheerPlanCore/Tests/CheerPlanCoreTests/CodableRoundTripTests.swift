import Foundation
import Testing
@testable import CheerPlanCore

@Suite struct CodableRoundTripTests {
    @Test func runnerPlanRoundTrips() throws {
        let course = try straightNorthCourse()
        let plan = RunnerPlan(
            name: "Rotterdam",
            course: course,
            startTime: raceStart,
            pacing: .splits([
                .init(distance: 5_000, secondsPerKilometer: 310),
                .init(distance: 5_000, secondsPerKilometer: 290)
            ])
        )
        let data = try JSONEncoder().encode(plan)
        let decoded = try JSONDecoder().decode(RunnerPlan.self, from: data)
        #expect(decoded == plan)
    }

    @Test func evaluatedItineraryRoundTrips() async throws {
        let course = try straightNorthCourse()
        let geometry = CourseGeometry(course: course)
        let plan = steadyPlan(course: course)
        let engine = FeasibilityEngine(provider: HeuristicTravelEstimator())
        let itinerary = try await engine.evaluate(
            spots: [
                PlannedSpot(meetPoint: geometry.meetPoint(atDistance: 2_000), travelMode: .walk),
                PlannedSpot(meetPoint: geometry.meetPoint(atDistance: 6_000), travelMode: .drive)
            ],
            plan: plan,
            spectatorStart: geometry.point(atDistance: 1_900).coordinate
        )
        let data = try JSONEncoder().encode(itinerary)
        let decoded = try JSONDecoder().decode(SupporterItinerary.self, from: data)
        #expect(decoded == itinerary)
    }

    @Test func observationsRoundTrip() throws {
        let observation = RunnerObservation(courseDistance: 21_097.5, timestamp: raceStart, source: .timingFeed)
        let data = try JSONEncoder().encode(observation)
        let decoded = try JSONDecoder().decode(RunnerObservation.self, from: data)
        #expect(decoded == observation)
    }

    @Test func milestonesRoundTrip() throws {
        let milestones = MilestoneGenerator.milestones(for: 42_195)
        let data = try JSONEncoder().encode(milestones)
        let decoded = try JSONDecoder().decode([Milestone].self, from: data)
        #expect(decoded == milestones)
    }
}
