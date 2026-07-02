import Foundation
import Testing
@testable import CheerPlanCore

@Suite struct FixSuggesterTests {
    let engine = FeasibilityEngine(provider: HeuristicTravelEstimator())

    @Test func infeasibleLegOffersModeChangeAndRemovals() async throws {
        let course = try straightNorthCourse()
        let geometry = CourseGeometry(course: course)
        let plan = steadyPlan(course: course)
        let spot1 = geometry.meetPoint(atDistance: 100, name: "Start corner")
        let spot2 = geometry.meetPoint(atDistance: 5_000, name: "Halfway")
        let itinerary = try await engine.evaluate(
            spots: [
                PlannedSpot(meetPoint: spot1, travelMode: .walk),
                PlannedSpot(meetPoint: spot2, travelMode: .walk)
            ],
            plan: plan,
            spectatorStart: geometry.point(atDistance: 0).coordinate
        )
        #expect(itinerary.legs[1].verdict.status == .notFeasible)

        let suggester = FixSuggester(engine: engine)
        let suggestions = try await suggester.suggestions(
            forLegAt: 1,
            in: itinerary,
            plans: [plan],
            geometry: geometry
        )

        // Driving catches the runner; cycling and transit do not.
        guard case .changeTravelMode(let mode, let verdict) = try #require(suggestions.first) else {
            Issue.record("expected a travel-mode change first, got \(suggestions)")
            return
        }
        #expect(mode == .drive)
        #expect(verdict.status == .ok)
        let modeChanges = suggestions.filter {
            if case .changeTravelMode = $0 { return true }
            return false
        }
        #expect(modeChanges.count == 1)

        // Walking can never catch a faster runner on a straight course: no move fix.
        let moves = suggestions.contains {
            if case .moveDestination = $0 { return true }
            return false
        }
        #expect(!moves)

        #expect(suggestions.contains(.removeDestinationSpot(spot2)))
        #expect(suggestions.contains(.removeSourceSpot(spot1)))
    }

    @Test func moveDestinationFindsNearestFeasibleDistance() async throws {
        let course = try straightNorthCourse()
        let geometry = CourseGeometry(course: course)
        let plan = steadyPlan(course: course)
        // Spectator lives near km 4 but picked a spot at km 0.5 — hopeless on foot,
        // but waiting further down the course works.
        let spot = geometry.meetPoint(atDistance: 500)
        let itinerary = try await engine.evaluate(
            spots: [PlannedSpot(meetPoint: spot, travelMode: .walk)],
            plan: plan,
            spectatorStart: geometry.point(atDistance: 4_000).coordinate
        )
        #expect(itinerary.legs[0].verdict.status == .notFeasible)

        let suggester = FixSuggester(engine: engine)
        let suggestions = try await suggester.suggestions(
            forLegAt: 0,
            in: itinerary,
            plans: [plan],
            geometry: geometry
        )

        guard case .moveDestination(let moved, let verdict) = try #require(suggestions.first) else {
            Issue.record("expected a move-destination fix first, got \(suggestions)")
            return
        }
        // First feasible 250 m step is km 3.25 (walk 750 m ≈ 722 s vs runner 975 s).
        #expect(approx(moved.courseDistance, 3_250, tolerance: 1))
        #expect(verdict.status != .notFeasible)

        // Origin is the spectator's start, so there is no source spot to remove.
        let removesSource = suggestions.contains {
            if case .removeSourceSpot = $0 { return true }
            return false
        }
        #expect(!removesSource)
        #expect(suggestions.contains(.removeDestinationSpot(spot)))
    }

    @Test func movedDestinationNeverOvertakesTheNextSpot() async throws {
        let course = try straightNorthCourse()
        let geometry = CourseGeometry(course: course)
        let plan = steadyPlan(course: course)
        // Same hopeless first spot, but a second spot at km 2 caps the search.
        let itinerary = try await engine.evaluate(
            spots: [
                PlannedSpot(meetPoint: geometry.meetPoint(atDistance: 500), travelMode: .walk),
                PlannedSpot(meetPoint: geometry.meetPoint(atDistance: 2_000), travelMode: .drive)
            ],
            plan: plan,
            spectatorStart: geometry.point(atDistance: 4_000).coordinate
        )
        let suggester = FixSuggester(engine: engine)
        let suggestions = try await suggester.suggestions(
            forLegAt: 0,
            in: itinerary,
            plans: [plan],
            geometry: geometry
        )
        // Feasibility on foot starts around km 3.05 — beyond the next spot, so no move fix.
        let moves = suggestions.contains {
            if case .moveDestination = $0 { return true }
            return false
        }
        #expect(!moves)
    }

    @Test func feasibleAndTightLegsGetNoSuggestions() async throws {
        let course = try straightNorthCourse()
        let geometry = CourseGeometry(course: course)
        let plan = steadyPlan(course: course)
        let itinerary = try await engine.evaluate(
            spots: [PlannedSpot(meetPoint: geometry.meetPoint(atDistance: 5_000), travelMode: .walk)],
            plan: plan,
            spectatorStart: geometry.point(atDistance: 4_900).coordinate
        )
        #expect(itinerary.legs[0].verdict.status == .ok)
        let suggester = FixSuggester(engine: engine)
        let suggestions = try await suggester.suggestions(
            forLegAt: 0,
            in: itinerary,
            plans: [plan],
            geometry: geometry
        )
        #expect(suggestions.isEmpty)
    }

    @Test func outOfRangeIndexIsEmpty() async throws {
        let suggester = FixSuggester(engine: engine)
        let suggestions = try await suggester.suggestions(
            forLegAt: 3,
            in: SupporterItinerary(),
            plans: [],
            geometry: CourseGeometry(course: try straightNorthCourse())
        )
        #expect(suggestions.isEmpty)
    }
}
