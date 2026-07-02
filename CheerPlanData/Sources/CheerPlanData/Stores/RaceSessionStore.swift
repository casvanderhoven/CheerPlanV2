import CheerPlanCore
import Foundation
import GRDB

/// Persistence seam for race sessions. Race day is the one moment data loss is
/// unforgivable (spec §6.5) — every mutation is committed before it returns.
public protocol RaceSessionStore: Sendable {
    /// The not-yet-ended session for a supporter plan, if one exists.
    func fetchActive(supporterPlanID: UUID) async throws -> RaceSession?
    func save(_ session: RaceSession) async throws
    func delete(id: UUID) async throws
}

struct RaceSessionRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "raceSession"

    var id: String
    var supporterPlanId: String
    var isEnded: Bool
    var document: Data

    init(session: RaceSession) throws {
        id = session.id.uuidString
        supporterPlanId = session.supporterPlanID.uuidString
        isEnded = session.isEnded
        document = try JSONEncoder().encode(session)
    }

    func session() throws -> RaceSession {
        try JSONDecoder().decode(RaceSession.self, from: document)
    }
}

public struct GRDBRaceSessionStore: RaceSessionStore {
    private let database: AppDatabase

    public init(database: AppDatabase) {
        self.database = database
    }

    public func fetchActive(supporterPlanID: UUID) async throws -> RaceSession? {
        let key = supporterPlanID.uuidString
        let record = try await database.writer.read { db in
            try RaceSessionRecord
                .filter(Column("supporterPlanId") == key)
                .filter(Column("isEnded") == false)
                .order(Column("id"))
                .fetchOne(db)
        }
        return try record?.session()
    }

    public func save(_ session: RaceSession) async throws {
        let record = try RaceSessionRecord(session: session)
        try await database.writer.write { db in
            try record.save(db)
        }
    }

    public func delete(id: UUID) async throws {
        let key = id.uuidString
        _ = try await database.writer.write { db in
            try RaceSessionRecord.deleteOne(db, key: key)
        }
    }
}

/// Previews and tests.
public actor InMemoryRaceSessionStore: RaceSessionStore {
    private var sessions: [UUID: RaceSession] = [:]

    public init() {}

    public func fetchActive(supporterPlanID: UUID) async throws -> RaceSession? {
        sessions.values
            .filter { $0.supporterPlanID == supporterPlanID && !$0.isEnded }
            .sorted { $0.id.uuidString < $1.id.uuidString }
            .first
    }

    public func save(_ session: RaceSession) async throws {
        sessions[session.id] = session
    }

    public func delete(id: UUID) async throws {
        sessions[id] = nil
    }
}
