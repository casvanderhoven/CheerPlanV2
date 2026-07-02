import CheerPlanCore
import Foundation
import GRDB

/// Persistence seam for supporter plans — one per runner plan for now
/// (multi-supporter crews arrive with M6).
public protocol SupporterPlanStore: Sendable {
    func fetch(runnerPlanID: UUID) async throws -> SupporterPlan?
    /// Inserts or updates; persists on every mutation.
    func save(_ plan: SupporterPlan) async throws
    func delete(id: UUID) async throws
}

/// Row mapping: scalar keys for lookup, the plan itself as a JSON document.
struct SupporterPlanRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "supporterPlan"

    var id: String
    var runnerPlanId: String
    var document: Data

    init(plan: SupporterPlan) throws {
        id = plan.id.uuidString
        runnerPlanId = plan.runnerPlanID.uuidString
        document = try JSONEncoder().encode(plan)
    }

    func plan() throws -> SupporterPlan {
        try JSONDecoder().decode(SupporterPlan.self, from: document)
    }
}

public struct GRDBSupporterPlanStore: SupporterPlanStore {
    private let database: AppDatabase

    public init(database: AppDatabase) {
        self.database = database
    }

    public func fetch(runnerPlanID: UUID) async throws -> SupporterPlan? {
        let key = runnerPlanID.uuidString
        let record = try await database.writer.read { db in
            try SupporterPlanRecord
                .filter(Column("runnerPlanId") == key)
                .order(Column("id"))
                .fetchOne(db)
        }
        return try record?.plan()
    }

    public func save(_ plan: SupporterPlan) async throws {
        let record = try SupporterPlanRecord(plan: plan)
        try await database.writer.write { db in
            try record.save(db)
        }
    }

    public func delete(id: UUID) async throws {
        let key = id.uuidString
        _ = try await database.writer.write { db in
            try SupporterPlanRecord.deleteOne(db, key: key)
        }
    }
}

/// Previews and tests.
public actor InMemorySupporterPlanStore: SupporterPlanStore {
    private var plans: [UUID: SupporterPlan]

    public init(plans: [SupporterPlan] = []) {
        self.plans = Dictionary(uniqueKeysWithValues: plans.map { ($0.id, $0) })
    }

    public func fetch(runnerPlanID: UUID) async throws -> SupporterPlan? {
        plans.values
            .filter { $0.runnerPlanID == runnerPlanID }
            .sorted { $0.id.uuidString < $1.id.uuidString }
            .first
    }

    public func save(_ plan: SupporterPlan) async throws {
        plans[plan.id] = plan
    }

    public func delete(id: UUID) async throws {
        plans[id] = nil
    }
}
