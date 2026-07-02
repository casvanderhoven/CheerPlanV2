import Foundation
import Testing
@testable import CheerPlanCore

@Suite struct PaceModelTests {
    @Test func steadyPaceBothDirections() {
        let model = PaceModel(pacing: .steady(secondsPerKilometer: 300), courseDistance: 10_000)
        #expect(model.time(atDistance: 0) == 0)
        #expect(approx(model.time(atDistance: 5_000), 1_500, tolerance: 1e-9))
        #expect(approx(model.totalDuration, 3_000, tolerance: 1e-9))
        #expect(approx(model.distance(atTime: 1_500), 5_000, tolerance: 1e-9))
        #expect(approx(model.distance(atTime: 3_000), 10_000, tolerance: 1e-9))
    }

    @Test func clampsToCourseAndDuration() {
        let model = PaceModel(pacing: .steady(secondsPerKilometer: 300), courseDistance: 10_000)
        #expect(model.time(atDistance: -100) == 0)
        #expect(model.time(atDistance: 20_000) == model.totalDuration)
        #expect(model.distance(atTime: -5) == 0)
        #expect(model.distance(atTime: 1e9) == 10_000)
    }

    @Test func negativeSplitMarathon() {
        let half = 21_097.5
        let pacing = PacingStrategy.splits([
            .init(distance: half, secondsPerKilometer: 310),
            .init(distance: half, secondsPerKilometer: 290)
        ])
        let model = PaceModel(pacing: pacing, courseDistance: 42_195)
        #expect(approx(model.time(atDistance: half), half * 0.310, tolerance: 0.001))
        let expectedTotal = half * 0.310 + (42_195 - half) * 0.290
        #expect(approx(model.totalDuration, expectedTotal, tolerance: 0.001))
        // in the middle of the second split the runner moves at 290 s/km
        let t1 = model.time(atDistance: 30_000)
        let t2 = model.time(atDistance: 31_000)
        #expect(approx(t2 - t1, 290, tolerance: 0.001))
    }

    @Test func splitsFallingShortExtendFinalPace() {
        let pacing = PacingStrategy.splits([
            .init(distance: 10_000, secondsPerKilometer: 300),
            .init(distance: 10_000, secondsPerKilometer: 360)
        ])
        let model = PaceModel(pacing: pacing, courseDistance: 30_000)
        // final 10 km continue at 360 s/km
        #expect(approx(model.totalDuration, 3_000 + 3_600 + 3_600, tolerance: 0.001))
    }

    @Test func splitsBeyondCourseAreClamped() {
        let model = PaceModel(
            pacing: .splits([.init(distance: 50_000, secondsPerKilometer: 300)]),
            courseDistance: 10_000
        )
        #expect(approx(model.totalDuration, 3_000, tolerance: 0.001))
        #expect(model.distance(atTime: 1e9) == 10_000)
    }

    @Test func emptySplitsFallBackToDefaultPace() {
        let model = PaceModel(pacing: .splits([]), courseDistance: 10_000)
        #expect(approx(model.totalDuration, 3_000, tolerance: 0.001)) // 5:00/km fallback
    }

    @Test func zeroLengthCourse() {
        let model = PaceModel(pacing: .steady(secondsPerKilometer: 300), courseDistance: 0)
        #expect(model.totalDuration == 0)
        #expect(model.distance(atTime: 100) == 0)
        #expect(model.time(atDistance: 100) == 0)
    }

    @Test func timeAndDistanceAreExactInverses() {
        let strategies: [PacingStrategy] = [
            .steady(secondsPerKilometer: 341),
            .splits([
                .init(distance: 5_000, secondsPerKilometer: 280),
                .init(distance: 16_097.5, secondsPerKilometer: 305),
                .init(distance: 15_000, secondsPerKilometer: 330),
                .init(distance: 6_097.5, secondsPerKilometer: 360)
            ])
        ]
        for pacing in strategies {
            let model = PaceModel(pacing: pacing, courseDistance: 42_195)
            var distance = 0.0
            while distance <= 42_195 {
                let roundTrip = model.distance(atTime: model.time(atDistance: distance))
                #expect(approx(roundTrip, distance, tolerance: 1e-6))
                distance += 1_055
            }
        }
    }

    @Test func targetFinishConvenience() {
        let pacing = PacingStrategy.targetFinish(courseDistance: 42_195, duration: 12_600) // 3h30
        let model = PaceModel(pacing: pacing, courseDistance: 42_195)
        #expect(approx(model.totalDuration, 12_600, tolerance: 0.01))
    }

    @Test func planArrivalTimesUseStartTime() throws {
        let course = try straightNorthCourse()
        let plan = steadyPlan(course: course, secondsPerKilometer: 300)
        let arrival = plan.arrivalTime(atDistance: 5_000)
        #expect(approx(arrival, raceStart.addingTimeInterval(1_500), tolerance: 0.5))
        #expect(approx(plan.plannedFinish, raceStart.addingTimeInterval(3_000), tolerance: 0.5))
    }
}
