import Foundation
import Testing
@testable import CheerPlanCore

@Suite struct HeuristicEstimatorTests {
    @Test func scalesWithModeAndDistance() async throws {
        let estimator = HeuristicTravelEstimator()
        let origin = Coordinate(latitude: 52.0, longitude: 4.0)
        let destination = Coordinate(latitude: 52.0 + 1000 / GeoMath.earthRadius * 180 / .pi, longitude: 4.0)

        let walk = try await estimator.travelEstimate(from: origin, to: destination, mode: .walk, departure: raceStart)
        #expect(approx(walk.duration, 1_300 / 1.35, tolerance: 1))
        #expect(walk.isEstimate)
        #expect(approx(walk.distance ?? 0, 1_300, tolerance: 2))

        let drive = try await estimator.travelEstimate(from: origin, to: destination, mode: .drive, departure: raceStart)
        #expect(approx(drive.duration, 1_500 / 8.3 + 120, tolerance: 1))

        let transit = try await estimator.travelEstimate(from: origin, to: destination, mode: .transit, departure: raceStart)
        #expect(approx(transit.duration, 1_400 / 5.5 + 300, tolerance: 1))

        let cycle = try await estimator.travelEstimate(from: origin, to: destination, mode: .cycle, departure: raceStart)
        #expect(approx(cycle.duration, 1_400 / 4.2 + 60, tolerance: 1))
    }

    @Test func zeroDistanceHasNoOverhead() async throws {
        let estimator = HeuristicTravelEstimator()
        let spot = Coordinate(latitude: 52.0, longitude: 4.0)
        let estimate = try await estimator.travelEstimate(from: spot, to: spot, mode: .transit, departure: raceStart)
        #expect(estimate.duration == 0)
    }
}

@Suite struct FeasibilityEngineTests {
    let engine = FeasibilityEngine(provider: HeuristicTravelEstimator())

    @Test func comfortableBufferIsOK() async throws {
        let course = try straightNorthCourse() // 10 km, runner at 300 s/km
        let geometry = CourseGeometry(course: course)
        let plan = steadyPlan(course: course)
        // spectator starts 100 m before the km-5 point
        let itinerary = try await engine.evaluate(
            spots: [PlannedSpot(meetPoint: geometry.meetPoint(atDistance: 5_000), travelMode: .walk)],
            plan: plan,
            spectatorStart: geometry.point(atDistance: 4_900).coordinate
        )
        let leg = try #require(itinerary.legs.first)
        #expect(leg.verdict.status == .ok)
        // walk ≈ 96 s, runner arrives at t+1500
        #expect(approx(leg.verdict.buffer, 1_500 - 100 * 1.3 / 1.35, tolerance: 5))
        #expect(approx(leg.runnerArrival, raceStart.addingTimeInterval(1_500), tolerance: 0.5))
        #expect(approx(leg.latestDeparture, raceStart.addingTimeInterval(1_500 - 100 * 1.3 / 1.35), tolerance: 5))
        #expect(itinerary.worstStatus == .ok)
    }

    @Test func smallPositiveBufferIsTight() async throws {
        let course = try straightNorthCourse()
        let geometry = CourseGeometry(course: course)
        let plan = steadyPlan(course: course)
        // travel ≈ 1450 s, runner arrives at 1500 s: buffer ≈ 50 s < required ≈ 145 s
        let itinerary = try await engine.evaluate(
            spots: [PlannedSpot(meetPoint: geometry.meetPoint(atDistance: 5_000), travelMode: .walk)],
            plan: plan,
            spectatorStart: geometry.point(atDistance: 3_494).coordinate
        )
        let leg = try #require(itinerary.legs.first)
        #expect(leg.verdict.status == .tight)
        #expect(leg.verdict.buffer > 0)
        #expect(leg.verdict.buffer < leg.verdict.requiredBuffer)
    }

    @Test func negativeBufferIsNotFeasible() async throws {
        let course = try straightNorthCourse()
        let geometry = CourseGeometry(course: course)
        let plan = steadyPlan(course: course)
        // walking the full 5 km takes ~4815 s; the runner needs 1500 s
        let itinerary = try await engine.evaluate(
            spots: [PlannedSpot(meetPoint: geometry.meetPoint(atDistance: 5_000), travelMode: .walk)],
            plan: plan,
            spectatorStart: geometry.point(atDistance: 0).coordinate
        )
        let leg = try #require(itinerary.legs.first)
        #expect(leg.verdict.status == .notFeasible)
        #expect(leg.verdict.buffer < 0)
        #expect(itinerary.worstStatus == .notFeasible)
    }

    @Test func departuresChainAfterTheRunnerPasses() async throws {
        // Same physical location on an out-and-back course: watch the 2 km pass,
        // stay put, watch the 8 km pass. Travel is zero; the departure for leg 2
        // must be the runner's pass at 2 km.
        let course = try Fixtures.course("out-and-back-10k")
        let geometry = CourseGeometry(course: course)
        let plan = steadyPlan(course: course)
        let spotCoordinate = geometry.point(atDistance: 2_000).coordinate
        let itinerary = try await engine.evaluate(
            spots: [
                PlannedSpot(meetPoint: geometry.meetPoint(atDistance: 2_000), travelMode: .walk),
                PlannedSpot(meetPoint: geometry.meetPoint(atDistance: 8_000), travelMode: .walk)
            ],
            plan: plan,
            spectatorStart: spotCoordinate
        )
        #expect(itinerary.legs.count == 2)
        let second = itinerary.legs[1]
        #expect(approx(second.departureTime, raceStart.addingTimeInterval(600), tolerance: 5))
        #expect(second.verdict.status == .ok)
        #expect(itinerary.worstStatus == .ok)
    }

    @Test func dwellDelaysTheNextDeparture() async throws {
        let course = try Fixtures.course("out-and-back-10k")
        let geometry = CourseGeometry(course: course)
        let plan = steadyPlan(course: course)
        let lingering = FeasibilityEngine(provider: HeuristicTravelEstimator(), dwell: 300)
        let itinerary = try await lingering.evaluate(
            spots: [
                PlannedSpot(meetPoint: geometry.meetPoint(atDistance: 2_000), travelMode: .walk),
                PlannedSpot(meetPoint: geometry.meetPoint(atDistance: 8_000), travelMode: .walk)
            ],
            plan: plan,
            spectatorStart: geometry.point(atDistance: 2_000).coordinate
        )
        #expect(approx(itinerary.legs[1].departureTime, raceStart.addingTimeInterval(900), tolerance: 5))
    }

    @Test func multiRunnerArrivesBeforeFirstLeavesAfterLast() async throws {
        let course = try straightNorthCourse()
        let geometry = CourseGeometry(course: course)
        let fast = steadyPlan(course: course, secondsPerKilometer: 300, name: "Fast")
        let slow = steadyPlan(course: course, secondsPerKilometer: 360, name: "Slow")
        let itinerary = try await engine.evaluate(
            spots: [
                PlannedSpot(meetPoint: geometry.meetPoint(atDistance: 3_000), travelMode: .walk),
                PlannedSpot(meetPoint: geometry.meetPoint(atDistance: 6_000), travelMode: .drive)
            ],
            plans: [fast, slow],
            spectatorStart: geometry.point(atDistance: 2_900).coordinate
        )
        // deadline at 3 km is the FAST runner (900 s), departure for the next leg
        // waits for the SLOW one (1080 s)
        #expect(approx(itinerary.legs[0].runnerArrival, raceStart.addingTimeInterval(900), tolerance: 0.5))
        #expect(approx(itinerary.legs[1].departureTime, raceStart.addingTimeInterval(1_080), tolerance: 0.5))
        #expect(approx(itinerary.legs[1].runnerArrival, raceStart.addingTimeInterval(1_800), tolerance: 0.5))
    }

    @Test func arrivalHelpersExposeTheWindow() throws {
        let course = try straightNorthCourse()
        let fast = steadyPlan(course: course, secondsPerKilometer: 300)
        let slow = steadyPlan(course: course, secondsPerKilometer: 360)
        let first = FeasibilityEngine.firstArrival(atDistance: 5_000, plans: [fast, slow])
        let last = FeasibilityEngine.lastArrival(atDistance: 5_000, plans: [fast, slow])
        #expect(approx(first, raceStart.addingTimeInterval(1_500), tolerance: 0.5))
        #expect(approx(last, raceStart.addingTimeInterval(1_800), tolerance: 0.5))
    }

    @Test func spotsAreOrderedByCourseDistance() async throws {
        let course = try straightNorthCourse()
        let geometry = CourseGeometry(course: course)
        let plan = steadyPlan(course: course)
        let itinerary = try await engine.evaluate(
            spots: [
                PlannedSpot(meetPoint: geometry.meetPoint(atDistance: 6_000), travelMode: .walk),
                PlannedSpot(meetPoint: geometry.meetPoint(atDistance: 2_000), travelMode: .walk)
            ],
            plan: plan,
            spectatorStart: geometry.point(atDistance: 1_900).coordinate
        )
        #expect(itinerary.spots.map(\.meetPoint.courseDistance) == [2_000, 6_000])
    }

    @Test func earlierDepartureBeatsTheGun() async throws {
        let course = try straightNorthCourse()
        let geometry = CourseGeometry(course: course)
        let plan = steadyPlan(course: course)
        // Leaving 30 min before the start makes a distant first spot reachable.
        let itinerary = try await engine.evaluate(
            spots: [PlannedSpot(meetPoint: geometry.meetPoint(atDistance: 2_000), travelMode: .walk)],
            plan: plan,
            spectatorStart: geometry.point(atDistance: 0).coordinate,
            earliestDeparture: raceStart.addingTimeInterval(-1_800)
        )
        let leg = try #require(itinerary.legs.first)
        #expect(leg.departureTime == raceStart.addingTimeInterval(-1_800))
        #expect(leg.verdict.status == .ok)
    }

    @Test func emptyPlansDegradeGracefully() async throws {
        let course = try straightNorthCourse()
        let geometry = CourseGeometry(course: course)
        let itinerary = try await engine.evaluate(
            spots: [PlannedSpot(meetPoint: geometry.meetPoint(atDistance: 2_000), travelMode: .walk)],
            plans: [],
            spectatorStart: geometry.point(atDistance: 0).coordinate
        )
        #expect(itinerary.legs.isEmpty)
        #expect(itinerary.spots.count == 1)
    }

    @Test func requiredBufferScalesWithTheLeg() {
        #expect(FeasibilityEngine.requiredBuffer(travelDuration: 600, mode: .walk) == 120)
        #expect(FeasibilityEngine.requiredBuffer(travelDuration: 3_600, mode: .walk) == 360)
        #expect(FeasibilityEngine.requiredBuffer(travelDuration: 600, mode: .drive) == 420)
        #expect(FeasibilityEngine.requiredBuffer(travelDuration: 600, mode: .transit) == 240)
    }
}
