import CheerPlanCore
import Foundation

public enum PlanStoreError: Error, Equatable, Sendable {
    case planNotFound(UUID)
}

/// The persistence seam for runner plans. One database for all documents
/// (v1 lesson #4 — no JSON files, no UserDefaults); implementations persist
/// on every mutation, and every failure is a thrown, user-surfaceable error.
public protocol PlanStore: Sendable {
    func fetchAll() async throws -> [RunnerPlan]
    func fetch(id: UUID) async throws -> RunnerPlan?
    /// Inserts or updates.
    func save(_ plan: RunnerPlan) async throws
    func delete(id: UUID) async throws
    /// Copies a plan under a fresh id with a distinguishable name; returns the copy.
    @discardableResult
    func duplicate(id: UUID) async throws -> RunnerPlan
}

extension RunnerPlan {
    /// The copy produced by "duplicate plan".
    func duplicated() -> RunnerPlan {
        RunnerPlan(name: name + " copy", course: course, startTime: startTime, pacing: pacing)
    }
}
