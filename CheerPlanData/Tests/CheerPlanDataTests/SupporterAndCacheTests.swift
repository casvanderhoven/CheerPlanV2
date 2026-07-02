import CheerPlanCore
import Foundation
import Testing
@testable import CheerPlanData

func sampleSupporterPlan(runnerPlanID: UUID = UUID()) throws -> SupporterPlan {
    let geometry = CourseGeometry(course: try sampleCourse())
    return SupporterPlan(
        runnerPlanID: runnerPlanID,
        spectatorStart: Coordinate(latitude: 52.001, longitude: 4.003),
        spots: [
            PlannedSpot(meetPoint: geometry.meetPoint(atDistance: 300), travelMode: .walk),
            PlannedSpot(meetPoint: geometry.meetPoint(atDistance: 700), travelMode: .drive)
        ]
    )
}

@Suite struct SupporterPlanStoreTests {
    @Test func grdbRoundTrip() async throws {
        let store = GRDBSupporterPlanStore(database: try AppDatabase.inMemory())
        let plan = try sampleSupporterPlan()
        try await store.save(plan)
        #expect(try await store.fetch(runnerPlanID: plan.runnerPlanID) == plan)

        var updated = plan
        updated.spots.removeLast()
        updated.earliestDeparture = Date(timeIntervalSince1970: 1_750_000_000)
        try await store.save(updated)
        #expect(try await store.fetch(runnerPlanID: plan.runnerPlanID) == updated)

        try await store.delete(id: plan.id)
        #expect(try await store.fetch(runnerPlanID: plan.runnerPlanID) == nil)
    }

    @Test func fetchIsScopedToTheRunnerPlan() async throws {
        let store = GRDBSupporterPlanStore(database: try AppDatabase.inMemory())
        let plan = try sampleSupporterPlan()
        try await store.save(plan)
        #expect(try await store.fetch(runnerPlanID: UUID()) == nil)
    }

    @Test func inMemoryMirrorsTheContract() async throws {
        let store = InMemorySupporterPlanStore()
        let plan = try sampleSupporterPlan()
        try await store.save(plan)
        #expect(try await store.fetch(runnerPlanID: plan.runnerPlanID) == plan)
        try await store.delete(id: plan.id)
        #expect(try await store.fetch(runnerPlanID: plan.runnerPlanID) == nil)
    }
}

/// Counts calls so cache hits are observable.
actor CountingProvider: TravelTimeProvider {
    private(set) var calls = 0

    func travelEstimate(
        from origin: Coordinate,
        to destination: Coordinate,
        mode: TravelMode,
        departure: Date
    ) async throws -> TravelEstimate {
        calls += 1
        return TravelEstimate(mode: mode, duration: 600, distance: 1_000, isEstimate: false)
    }
}

@Suite struct CachedTravelTimeProviderTests {
    let origin = Coordinate(latitude: 52.37021, longitude: 4.89517)
    let destination = Coordinate(latitude: 52.38004, longitude: 4.90998)
    let departure = Date(timeIntervalSince1970: 1_750_000_000)

    @Test func identicalRequestsHitTheCache() async throws {
        let inner = CountingProvider()
        let provider = CachedTravelTimeProvider(
            wrapping: inner,
            database: try AppDatabase.inMemory(),
            now: { Date(timeIntervalSince1970: 1_749_999_000) }
        )
        let first = try await provider.travelEstimate(from: origin, to: destination, mode: .drive, departure: departure)
        let second = try await provider.travelEstimate(from: origin, to: destination, mode: .drive, departure: departure)
        #expect(first == second)
        #expect(await inner.calls == 1)
        // a nearby departure inside the same 15-minute bucket also hits
        _ = try await provider.travelEstimate(
            from: origin,
            to: destination,
            mode: .drive,
            departure: departure.addingTimeInterval(60)
        )
        #expect(await inner.calls == 1)
    }

    @Test func differentModeOrBucketMisses() async throws {
        let inner = CountingProvider()
        let provider = CachedTravelTimeProvider(
            wrapping: inner,
            database: try AppDatabase.inMemory(),
            now: { Date(timeIntervalSince1970: 1_749_999_000) }
        )
        _ = try await provider.travelEstimate(from: origin, to: destination, mode: .drive, departure: departure)
        _ = try await provider.travelEstimate(from: origin, to: destination, mode: .walk, departure: departure)
        _ = try await provider.travelEstimate(
            from: origin,
            to: destination,
            mode: .drive,
            departure: departure.addingTimeInterval(3_600)
        )
        #expect(await inner.calls == 3)
    }

    @Test func expiredEntriesRefetch() async throws {
        let inner = CountingProvider()
        let database = try AppDatabase.inMemory()
        let clock = ClockBox(start: Date(timeIntervalSince1970: 1_749_999_000))
        let provider = CachedTravelTimeProvider(
            wrapping: inner,
            database: database,
            timeToLive: 10,
            now: { clock.now }
        )
        _ = try await provider.travelEstimate(from: origin, to: destination, mode: .drive, departure: departure)
        clock.advance(by: 60)
        _ = try await provider.travelEstimate(from: origin, to: destination, mode: .drive, departure: departure)
        #expect(await inner.calls == 2)
    }
}

/// A tiny mutable clock for TTL tests.
final class ClockBox: @unchecked Sendable {
    private let lock = NSLock()
    private var current: Date

    init(start: Date) {
        current = start
    }

    var now: Date {
        lock.withLock { current }
    }

    func advance(by interval: TimeInterval) {
        lock.withLock { current = current.addingTimeInterval(interval) }
    }
}
