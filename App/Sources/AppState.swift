import CheerPlanCore
import CheerPlanData
import Foundation
import Observation

/// App-wide observable state, injected via the environment — no mutable statics.
@MainActor
@Observable
final class AppState {
    let planStore: any PlanStore
    let travelTimeProvider: any TravelTimeProvider
    let startupError: String?

    private(set) var plans: [RunnerPlan] = []
    /// The latest user-visible error. Every failable operation reports here —
    /// never print-and-swallow (spec §5).
    var errorMessage: String?

    init(dependencies: Dependencies) {
        self.planStore = dependencies.planStore
        self.travelTimeProvider = dependencies.travelTimeProvider
        self.startupError = dependencies.startupError
    }

    func plan(id: UUID) -> RunnerPlan? {
        plans.first { $0.id == id }
    }

    func loadPlans() async {
        do {
            plans = try await planStore.fetchAll()
        } catch {
            errorMessage = "Couldn't load your plans: \(error.localizedDescription)"
        }
    }

    func save(_ plan: RunnerPlan) async {
        do {
            try await planStore.save(plan)
            await loadPlans()
        } catch {
            errorMessage = "Couldn't save \"\(plan.name)\": \(error.localizedDescription)"
        }
    }

    func delete(_ plan: RunnerPlan) async {
        do {
            try await planStore.delete(id: plan.id)
            await loadPlans()
        } catch {
            errorMessage = "Couldn't delete \"\(plan.name)\": \(error.localizedDescription)"
        }
    }

    func duplicate(_ plan: RunnerPlan) async {
        do {
            try await planStore.duplicate(id: plan.id)
            await loadPlans()
        } catch {
            errorMessage = "Couldn't duplicate \"\(plan.name)\": \(error.localizedDescription)"
        }
    }
}
