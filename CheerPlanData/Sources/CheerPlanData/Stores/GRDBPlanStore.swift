import CheerPlanCore
import Foundation
import GRDB

/// GRDB-backed `PlanStore`. Every mutation is a committed write before the
/// call returns — nothing lives only in memory.
public struct GRDBPlanStore: PlanStore {
    private let database: AppDatabase

    public init(database: AppDatabase) {
        self.database = database
    }

    public func fetchAll() async throws -> [RunnerPlan] {
        let records = try await database.writer.read { db in
            try RunnerPlanRecord
                .order(Column("name"), Column("id"))
                .fetchAll(db)
        }
        return try records.map { try $0.plan() }
    }

    public func fetch(id: UUID) async throws -> RunnerPlan? {
        let key = id.uuidString
        let record = try await database.writer.read { db in
            try RunnerPlanRecord.fetchOne(db, key: key)
        }
        return try record?.plan()
    }

    public func save(_ plan: RunnerPlan) async throws {
        let record = try RunnerPlanRecord(plan: plan)
        try await database.writer.write { db in
            try record.save(db)
        }
    }

    public func delete(id: UUID) async throws {
        let key = id.uuidString
        _ = try await database.writer.write { db in
            try RunnerPlanRecord.deleteOne(db, key: key)
        }
    }

    @discardableResult
    public func duplicate(id: UUID) async throws -> RunnerPlan {
        guard let original = try await fetch(id: id) else {
            throw PlanStoreError.planNotFound(id)
        }
        let copy = original.duplicated()
        try await save(copy)
        return copy
    }
}
