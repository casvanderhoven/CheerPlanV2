import Foundation
import GRDB

/// The single database (spec §5: one database for everything).
/// Migrations run at construction, so a handed-out `AppDatabase` is always usable.
public struct AppDatabase: Sendable {
    public let writer: any DatabaseWriter

    public init(_ writer: any DatabaseWriter) throws {
        self.writer = writer
        try Self.migrator.migrate(writer)
    }

    /// The on-disk database in Application Support.
    public static func onDisk() throws -> AppDatabase {
        let directory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let url = directory.appendingPathComponent("cheerplan.sqlite")
        return try AppDatabase(DatabaseQueue(path: url.path))
    }

    /// An in-memory database for previews and tests.
    public static func inMemory() throws -> AppDatabase {
        try AppDatabase(DatabaseQueue())
    }

    static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1-runnerPlan") { db in
            try db.create(table: "runnerPlan") { table in
                table.primaryKey("id", .text)
                table.column("name", .text).notNull()
                table.column("startTime", .datetime).notNull()
                // Course and pacing are documents, not relational data:
                // stored as JSON so the schema stays stable while Core evolves.
                table.column("courseData", .blob).notNull()
                table.column("pacingData", .blob).notNull()
            }
        }
        migrator.registerMigration("v2-supporter-and-travel-cache") { db in
            try db.create(table: "supporterPlan") { table in
                table.primaryKey("id", .text)
                table.column("runnerPlanId", .text).notNull().indexed()
                table.column("document", .blob).notNull()
            }
            try db.create(table: "travelCache") { table in
                table.primaryKey("key", .text)
                table.column("mode", .text).notNull()
                table.column("duration", .double).notNull()
                table.column("distance", .double)
                table.column("isEstimate", .boolean).notNull()
                table.column("expiresAt", .datetime).notNull()
            }
        }
        return migrator
    }
}
