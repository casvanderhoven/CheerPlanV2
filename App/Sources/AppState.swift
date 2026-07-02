import CheerPlanCore
import CheerPlanData
import Foundation
import Observation

/// App-wide observable state, injected via the environment — no mutable statics.
@MainActor
@Observable
final class AppState {
    let planStore: any PlanStore
    let supporterPlanStore: any SupporterPlanStore
    let travelTimeProvider: any TravelTimeProvider
    let startupError: String?

    private(set) var plans: [RunnerPlan] = []
    /// The latest user-visible error. Every failable operation reports here —
    /// never print-and-swallow (spec §5).
    var errorMessage: String?

    init(dependencies: Dependencies) {
        self.planStore = dependencies.planStore
        self.supporterPlanStore = dependencies.supporterPlanStore
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

    /// Handles share links (`cheerplan://`, `https://cheerplan.app/...`) and
    /// `.cheerplan` files arriving via "open with".
    func handleIncomingURL(_ url: URL) async {
        do {
            let plan: RunnerPlan
            if url.isFileURL {
                let accessing = url.startAccessingSecurityScopedResource()
                defer {
                    if accessing {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                plan = try PlanShareCodec.decodePlan(fromFileData: try Data(contentsOf: url))
            } else {
                plan = try PlanShareCodec.decodePlan(from: url)
            }
            try await planStore.save(plan)
            await loadPlans()
        } catch ShareCodecError.unsupportedVersion {
            errorMessage = "This plan was shared from a newer version of CheerPlan. Update the app and try again."
        } catch ShareCodecError.notAShareLink {
            errorMessage = "That link isn't a CheerPlan plan."
        } catch {
            errorMessage = "Couldn't import the shared plan: \(error.localizedDescription)"
        }
    }
}
