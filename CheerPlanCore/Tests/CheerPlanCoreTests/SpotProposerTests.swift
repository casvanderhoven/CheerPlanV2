import Foundation
import Testing
@testable import CheerPlanCore

@Suite struct SpotProposerTests {
    let engine = FeasibilityEngine(provider: HeuristicTravelEstimator())

    @Test func picksKilometerMarkerAndIconicMilestone() async throws {
        // Slow runner (10:00/km), spectator drives: everything downstream is reachable,
        // so the scorer decides. Expected picks are exact: km 3 (marker beats the
        // anonymous grid points in its window), then the 5K sign (iconic beats all).
        let course = try straightNorthCourse() // 10 km
        let geometry = CourseGeometry(course: course)
        let plan = steadyPlan(course: course, secondsPerKilometer: 600)
        let proposer = SpotProposer(engine: engine)
        let itinerary = try await proposer.propose(
            SpotProposer.Request(
                plan: plan,
                spectatorStart: geometry.point(atDistance: 0).coordinate,
                travelMode: .drive,
                desiredCount: 2
            )
        )
        #expect(itinerary.spots.count == 2)
        #expect(itinerary.spots.map(\.meetPoint.courseDistance) == [3_000, 5_000])
        #expect(itinerary.spots[0].meetPoint.name == "km 3")
        #expect(itinerary.spots[1].meetPoint.name == "5K")
        #expect(itinerary.legs.allSatisfy { $0.verdict.status == .ok })
    }

    @Test func proposalsOnARealMarathonAreFeasibleAndSpaced() async throws {
        let course = try Fixtures.course("marathon-city")
        let plan = steadyPlan(course: course, secondsPerKilometer: 360)
        let proposer = SpotProposer(engine: engine)
        let request = SpotProposer.Request(
            plan: plan,
            spectatorStart: CourseGeometry(course: course).point(atDistance: 0).coordinate,
            travelMode: .drive,
            desiredCount: 4
        )
        let itinerary = try await proposer.propose(request)

        #expect(!itinerary.spots.isEmpty)
        #expect(itinerary.spots.count <= 4)
        #expect(itinerary.legs.count == itinerary.spots.count)
        #expect(itinerary.legs.allSatisfy { $0.verdict.status != .notFeasible })
        let distances = itinerary.spots.map(\.meetPoint.courseDistance)
        #expect(distances == distances.sorted())
        for (a, b) in zip(distances, distances.dropFirst()) {
            #expect(b - a >= request.minSpacing)
        }
    }

    @Test func fallsBackToTightWhenNothingIsComfortable() async throws {
        // On a short course with a fast runner, driving never reaches OK
        // (the parking buffer eats the margin), but tight sightings exist.
        let course = try straightNorthCourse(segments: 3) // 3 km
        let geometry = CourseGeometry(course: course)
        let plan = steadyPlan(course: course, secondsPerKilometer: 300)
        let proposer = SpotProposer(engine: engine)
        let itinerary = try await proposer.propose(
            SpotProposer.Request(
                plan: plan,
                spectatorStart: geometry.point(atDistance: 0).coordinate,
                travelMode: .drive,
                desiredCount: 3
            )
        )
        #expect(itinerary.spots.map(\.meetPoint.courseDistance) == [1_500, 3_000])
        #expect(itinerary.legs.allSatisfy { $0.verdict.status == .tight })
        #expect(itinerary.worstStatus == .tight)
    }

    @Test func multiRunnerProposalCoversEveryRunner() async throws {
        let course = try straightNorthCourse()
        let geometry = CourseGeometry(course: course)
        let fast = steadyPlan(course: course, secondsPerKilometer: 540, name: "Fast")
        let slow = steadyPlan(course: course, secondsPerKilometer: 600, name: "Slow")
        let proposer = SpotProposer(engine: engine)
        let itinerary = try await proposer.propose(
            SpotProposer.Request(
                plans: [fast, slow],
                spectatorStart: geometry.point(atDistance: 0).coordinate,
                travelMode: .drive,
                desiredCount: 3
            )
        )
        #expect(!itinerary.spots.isEmpty)
        #expect(itinerary.legs.allSatisfy { $0.verdict.status != .notFeasible })
        for (index, leg) in itinerary.legs.enumerated() {
            let distance = itinerary.spots[index].meetPoint.courseDistance
            // arrive before the first runner...
            #expect(leg.runnerArrival == FeasibilityEngine.firstArrival(atDistance: distance, plans: [fast, slow]))
            // ...and only depart for the next spot after the last one has passed
            if index + 1 < itinerary.legs.count {
                let departure = itinerary.legs[index + 1].departureTime
                #expect(departure == FeasibilityEngine.lastArrival(atDistance: distance, plans: [fast, slow]))
            }
        }
    }

    @Test func zeroDesiredCountIsEmpty() async throws {
        let course = try straightNorthCourse()
        let plan = steadyPlan(course: course)
        let proposer = SpotProposer(engine: engine)
        let itinerary = try await proposer.propose(
            SpotProposer.Request(
                plan: plan,
                spectatorStart: Coordinate(latitude: 52, longitude: 4),
                desiredCount: 0
            )
        )
        #expect(itinerary.spots.isEmpty)
        #expect(itinerary.legs.isEmpty)
    }

    @Test func candidateGridSkipsNearMilestones() throws {
        let course = try straightNorthCourse() // 10 km
        let proposer = SpotProposer(engine: engine)
        let candidates = proposer.candidateDistances(for: course)
        let distances = candidates.map(\.distance)
        #expect(distances == distances.sorted())
        // milestone km 1 present, its grid twin suppressed
        #expect(distances.contains(1_000))
        #expect(distances.filter { approx($0, 1_000, tolerance: 250) }.count == 1)
        // plain grid point between markers present
        #expect(distances.contains(1_500))
    }
}
