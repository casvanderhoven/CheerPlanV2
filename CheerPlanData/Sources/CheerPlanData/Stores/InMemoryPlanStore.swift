import CheerPlanCore
import Foundation

/// Previews and tests. An actor, so it satisfies `Sendable` without locks.
public actor InMemoryPlanStore: PlanStore {
    private var plans: [UUID: RunnerPlan]

    public init(plans: [RunnerPlan] = []) {
        self.plans = Dictionary(uniqueKeysWithValues: plans.map { ($0.id, $0) })
    }

    public func fetchAll() async throws -> [RunnerPlan] {
        plans.values.sorted {
            ($0.name, $0.id.uuidString) < ($1.name, $1.id.uuidString)
        }
    }

    public func fetch(id: UUID) async throws -> RunnerPlan? {
        plans[id]
    }

    public func save(_ plan: RunnerPlan) async throws {
        plans[plan.id] = plan
    }

    public func delete(id: UUID) async throws {
        plans[id] = nil
    }

    @discardableResult
    public func duplicate(id: UUID) async throws -> RunnerPlan {
        guard let original = plans[id] else {
            throw PlanStoreError.planNotFound(id)
        }
        let copy = original.duplicated()
        plans[copy.id] = copy
        return copy
    }
}
