import CheerPlanCore
import CheerPlanData
import Foundation
import Observation

/// Per-screen model for the supporter flow: owns the `SupporterPlan` document,
/// persists on every mutation, and recomputes the itinerary after each change —
/// the engine's `evaluate` is the single source of truth for verdicts.
@MainActor
@Observable
final class SupporterPlanModel {
    let runnerPlan: RunnerPlan
    let geometry: CourseGeometry
    private let store: any SupporterPlanStore
    private let planStore: any PlanStore
    private let engine: FeasibilityEngine

    private(set) var plan: SupporterPlan
    private(set) var itinerary = SupporterItinerary()
    /// The primary runner plus everyone added via the Runners menu (M6).
    private(set) var trackedPlans: [RunnerPlan]
    private(set) var isEvaluating = false
    var errorMessage: String?

    init(
        runnerPlan: RunnerPlan,
        store: any SupporterPlanStore,
        planStore: any PlanStore,
        travelProvider: any TravelTimeProvider
    ) {
        self.runnerPlan = runnerPlan
        self.geometry = CourseGeometry(course: runnerPlan.course)
        self.store = store
        self.planStore = planStore
        self.engine = FeasibilityEngine(provider: travelProvider)
        self.plan = SupporterPlan(runnerPlanID: runnerPlan.id)
        self.trackedPlans = [runnerPlan]
    }

    func load() async {
        do {
            if let existing = try await store.fetch(runnerPlanID: runnerPlan.id) {
                plan = existing
            } else {
                try await store.save(plan)
            }
            await resolveTrackedPlans()
            await evaluate()
        } catch {
            errorMessage = "Couldn't load your cheering plan: \(error.localizedDescription)"
        }
    }

    // MARK: - Multi-runner (M6)

    func isTracking(_ other: RunnerPlan) -> Bool {
        plan.additionalRunnerPlanIDs?.contains(other.id) ?? false
    }

    func toggleRunner(_ other: RunnerPlan) async {
        var ids = plan.additionalRunnerPlanIDs ?? []
        if let index = ids.firstIndex(of: other.id) {
            ids.remove(at: index)
        } else {
            ids.append(other.id)
        }
        plan.additionalRunnerPlanIDs = ids.isEmpty ? nil : ids
        await resolveTrackedPlans()
        await persistAndEvaluate()
    }

    /// First-to-last runner window at a spot — what "see everyone" costs.
    func passWindow(atDistance distance: Double) -> (first: Date, last: Date)? {
        guard trackedPlans.count > 1 else { return nil }
        return (
            FeasibilityEngine.firstArrival(atDistance: distance, plans: trackedPlans),
            FeasibilityEngine.lastArrival(atDistance: distance, plans: trackedPlans)
        )
    }

    private func resolveTrackedPlans() async {
        var plans = [runnerPlan]
        for id in plan.additionalRunnerPlanIDs ?? [] {
            // A deleted runner plan silently drops out of the crew view.
            if let extra = try? await planStore.fetch(id: id) {
                plans.append(extra)
            }
        }
        trackedPlans = plans
    }

    // MARK: - Crew assignments (M6)

    func assignee(forSpot id: UUID) -> String? {
        plan.spots.first { $0.id == id }?.assignee
    }

    func setAssignee(_ name: String?, forSpot id: UUID) async {
        guard let index = plan.spots.firstIndex(where: { $0.id == id }) else { return }
        plan.spots[index].assignee = name
        await persistAndEvaluate()
    }

    // MARK: - Mutations (each persists, then re-evaluates)

    func addSpot(atCourseDistance distance: Double) async {
        let meetPoint = geometry.meetPoint(atDistance: distance)
        plan.spots.append(PlannedSpot(meetPoint: meetPoint, travelMode: defaultMode))
        sortSpots()
        await persistAndEvaluate()
    }

    func removeSpot(id: UUID) async {
        plan.spots.removeAll { $0.id == id }
        await persistAndEvaluate()
    }

    func setMode(_ mode: TravelMode, forSpot id: UUID) async {
        guard let index = plan.spots.firstIndex(where: { $0.id == id }) else { return }
        plan.spots[index].travelMode = mode
        await persistAndEvaluate()
    }

    func setStart(_ coordinate: Coordinate) async {
        plan.spectatorStart = coordinate
        await persistAndEvaluate()
    }

    func apply(_ fix: FixSuggestion, toLegAt index: Int) async {
        guard itinerary.spots.indices.contains(index) else { return }
        let spotID = itinerary.spots[index].id
        switch fix {
        case .changeTravelMode(let mode, _):
            await setMode(mode, forSpot: spotID)
        case .moveDestination(let moved, _):
            if let spotIndex = plan.spots.firstIndex(where: { $0.id == spotID }) {
                plan.spots[spotIndex].meetPoint = moved
                sortSpots()
                await persistAndEvaluate()
            }
        case .removeDestinationSpot(let meetPoint), .removeSourceSpot(let meetPoint):
            await removeSpot(id: meetPoint.id)
        }
    }

    func propose(count: Int, mode: TravelMode) async {
        guard let start = plan.spectatorStart else {
            errorMessage = "Set your starting point first — tap the map away from the course."
            return
        }
        isEvaluating = true
        defer { isEvaluating = false }
        do {
            let proposer = SpotProposer(engine: engine)
            let proposed = try await proposer.propose(
                SpotProposer.Request(
                    plans: trackedPlans,
                    spectatorStart: start,
                    earliestDeparture: plan.earliestDeparture,
                    travelMode: mode,
                    desiredCount: count
                )
            )
            plan.spots = proposed.spots
            try await store.save(plan)
            itinerary = proposed
        } catch {
            errorMessage = "Auto-propose failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Queries

    func suggestions(forLegAt index: Int) async -> [FixSuggestion] {
        do {
            let suggester = FixSuggester(engine: engine)
            return try await suggester.suggestions(
                forLegAt: index,
                in: itinerary,
                plans: [runnerPlan],
                geometry: geometry
            )
        } catch {
            errorMessage = "Couldn't compute fixes: \(error.localizedDescription)"
            return []
        }
    }

    /// Verdict tint for a spot's map marker.
    func status(forSpot id: UUID) -> FeasibilityStatus? {
        guard let index = itinerary.spots.firstIndex(where: { $0.id == id }),
              itinerary.legs.indices.contains(index) else {
            return nil
        }
        return itinerary.legs[index].verdict.status
    }

    // MARK: - Internals

    private var defaultMode: TravelMode {
        plan.spots.last?.travelMode ?? .walk
    }

    private func sortSpots() {
        plan.spots.sort { $0.meetPoint.courseDistance < $1.meetPoint.courseDistance }
    }

    private func persistAndEvaluate() async {
        do {
            try await store.save(plan)
        } catch {
            errorMessage = "Couldn't save your cheering plan: \(error.localizedDescription)"
        }
        await evaluate()
    }

    private func evaluate() async {
        // Until the supporter picks a start, assume they begin at the course start.
        guard let start = plan.spectatorStart ?? runnerPlan.course.start else { return }
        isEvaluating = true
        defer { isEvaluating = false }
        do {
            itinerary = try await engine.evaluate(
                spots: plan.spots,
                plans: trackedPlans,
                spectatorStart: start,
                earliestDeparture: plan.earliestDeparture
            )
        } catch {
            errorMessage = "Couldn't evaluate the itinerary: \(error.localizedDescription)"
        }
    }
}
