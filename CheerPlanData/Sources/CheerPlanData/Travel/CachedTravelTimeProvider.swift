import CheerPlanCore
import Foundation
import GRDB

/// On-disk travel-time cache (spec §5): keyed by endpoints rounded to ~10 m,
/// mode, and a 15-minute departure bucket, with a TTL. Decorates any provider,
/// so real MapKit routing gets cached and race day works offline once planned.
public struct CachedTravelTimeProvider: TravelTimeProvider {
    public let inner: any TravelTimeProvider
    private let database: AppDatabase
    private let timeToLive: TimeInterval
    private let now: @Sendable () -> Date

    public init(
        wrapping inner: any TravelTimeProvider,
        database: AppDatabase,
        timeToLive: TimeInterval = 6 * 3600,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.inner = inner
        self.database = database
        self.timeToLive = timeToLive
        self.now = now
    }

    public func travelEstimate(
        from origin: Coordinate,
        to destination: Coordinate,
        mode: TravelMode,
        departure: Date
    ) async throws -> TravelEstimate {
        let key = Self.cacheKey(from: origin, to: destination, mode: mode, departure: departure)
        if let cached = try await cachedEstimate(key: key, mode: mode) {
            return cached
        }
        let estimate = try await inner.travelEstimate(
            from: origin,
            to: destination,
            mode: mode,
            departure: departure
        )
        try await store(estimate, key: key)
        return estimate
    }

    /// "52.3702,4.9001>52.3800,4.9100|drive|123456" — endpoints at 1e-4°,
    /// departure bucketed to 15 minutes.
    static func cacheKey(from origin: Coordinate, to destination: Coordinate, mode: TravelMode, departure: Date) -> String {
        let bucket = Int((departure.timeIntervalSince1970 / 900).rounded(.down))
        return rounded(origin) + ">" + rounded(destination) + "|" + mode.rawValue + "|" + String(bucket)
    }

    private static func rounded(_ coordinate: Coordinate) -> String {
        String(format: "%.4f,%.4f", coordinate.latitude, coordinate.longitude)
    }

    private func cachedEstimate(key: String, mode: TravelMode) async throws -> TravelEstimate? {
        let record = try await database.writer.read { db in
            try TravelCacheRecord.fetchOne(db, key: key)
        }
        guard let record, record.expiresAt > now() else { return nil }
        return TravelEstimate(
            mode: TravelMode(rawValue: record.mode) ?? mode,
            duration: record.duration,
            distance: record.distance,
            isEstimate: record.isEstimate
        )
    }

    private func store(_ estimate: TravelEstimate, key: String) async throws {
        let record = TravelCacheRecord(
            key: key,
            mode: estimate.mode.rawValue,
            duration: estimate.duration,
            distance: estimate.distance,
            isEstimate: estimate.isEstimate,
            expiresAt: now().addingTimeInterval(timeToLive)
        )
        try await database.writer.write { db in
            try record.save(db)
        }
    }
}

struct TravelCacheRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "travelCache"

    var key: String
    var mode: String
    var duration: Double
    var distance: Double?
    var isEstimate: Bool
    var expiresAt: Date
}
