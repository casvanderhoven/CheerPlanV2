import Foundation
import Testing
@testable import CheerPlanCore

@Suite struct ProgressEstimatorTests {
    func tenKPlan() throws -> RunnerPlan {
        steadyPlan(course: try straightNorthCourse(), secondsPerKilometer: 300)
    }

    /// An observation `elapsed` seconds into the race.
    func observed(
        _ distance: Double,
        at elapsed: TimeInterval,
        source: RunnerObservation.Source = .checkIn
    ) -> RunnerObservation {
        RunnerObservation(courseDistance: distance, timestamp: raceStart.addingTimeInterval(elapsed), source: source)
    }

    @Test func noObservationsFollowsThePlan() throws {
        let estimator = ProgressEstimator(plan: try tenKPlan())
        #expect(approx(estimator.projectedArrival(atDistance: 5_000), raceStart.addingTimeInterval(1_500), tolerance: 0.5))
        #expect(estimator.paceRatio == 1)
        #expect(estimator.scheduleDelta == 0)
        #expect(approx(estimator.estimatedDistance(at: raceStart.addingTimeInterval(900)), 3_000, tolerance: 1))
    }

    @Test func behindPlanObservationSlowsAllProjections() throws {
        var estimator = ProgressEstimator(plan: try tenKPlan())
        // Planned at km 5: 1500 s. Observed: 1650 s → 10% slow.
        estimator.record(observed(5_000, at: 1_650))
        #expect(approx(estimator.paceRatio, 1.1, tolerance: 1e-6))
        #expect(approx(estimator.scheduleDelta, 150, tolerance: 1e-6))
        // km 6: anchor + 300 planned seconds × 1.1
        #expect(approx(estimator.projectedArrival(atDistance: 6_000), raceStart.addingTimeInterval(1_650 + 330), tolerance: 0.5))
        #expect(approx(estimator.projectedFinish, raceStart.addingTimeInterval(1_650 + 1_500 * 1.1), tolerance: 0.5))
        // position now and later
        #expect(approx(estimator.estimatedDistance(at: raceStart.addingTimeInterval(1_650)), 5_000, tolerance: 1))
        #expect(approx(estimator.estimatedDistance(at: raceStart.addingTimeInterval(1_980)), 6_000, tolerance: 1))
    }

    @Test func aheadOfPlanObservationSpeedsProjections() throws {
        var estimator = ProgressEstimator(plan: try tenKPlan())
        estimator.record(observed(5_000, at: 1_350, source: .timingFeed))
        #expect(estimator.paceRatio < 1)
        #expect(approx(estimator.scheduleDelta, -150, tolerance: 1e-6))
        #expect(estimator.projectedFinish < raceStart.addingTimeInterval(3_000))
    }

    @Test func recentSegmentDominatesTheCumulativeAverage() throws {
        var estimator = ProgressEstimator(plan: try tenKPlan())
        // On plan at km 4 (1200 s), then a 450 s split for a planned-300 s segment.
        estimator.record(observed(4_000, at: 1_200))
        estimator.record(observed(5_000, at: 1_650))
        // 0.7 × (450/300) + 0.3 × (1650/1500) = 1.38 — closer to the recent 1.5 than to 1.1
        #expect(approx(estimator.paceRatio, 1.38, tolerance: 1e-6))
        #expect(abs(estimator.paceRatio - 1.5) < abs(estimator.paceRatio - 1.1))
    }

    @Test func veryEarlyObservationsCarryNoSignal() throws {
        var estimator = ProgressEstimator(plan: try tenKPlan())
        // Planned elapsed at 100 m is 30 s — under the one-minute floor.
        estimator.record(observed(100, at: 45))
        #expect(estimator.paceRatio == 1)
    }

    @Test func paceRatioIsClamped() throws {
        var estimator = ProgressEstimator(plan: try tenKPlan())
        estimator.record(observed(5_000, at: 9_000, source: .recalibration))
        #expect(estimator.paceRatio == 3)
    }

    @Test func observationsStaySortedByTime() throws {
        var estimator = ProgressEstimator(plan: try tenKPlan())
        let later = observed(5_000, at: 1_650)
        let earlier = observed(4_000, at: 1_200)
        estimator.record(later)
        estimator.record(earlier)
        #expect(estimator.latest == later)
        #expect(estimator.observations.map(\.courseDistance) == [4_000, 5_000])
    }

    @Test func projectionsClampAtTheFinish() throws {
        var estimator = ProgressEstimator(plan: try tenKPlan())
        estimator.record(observed(5_000, at: 1_650))
        #expect(approx(estimator.estimatedDistance(at: raceStart.addingTimeInterval(100_000)), 10_000, tolerance: 0.01))
    }
}
