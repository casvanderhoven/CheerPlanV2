import CheerPlanCore
import Foundation
import GRDB
import Testing
@testable import CheerPlanData

func sampleCourse() throws -> Course {
    let coordinates: [(coordinate: Coordinate, elevation: Double?)] = (0...10).map { index in
        (Coordinate(latitude: 52.0 + Double(index) * 0.009, longitude: 4.0), Double(index))
    }
    return try Course(name: "Test course", coordinates: coordinates)
}

func samplePlan(name: String = "Rotterdam") throws -> RunnerPlan {
    RunnerPlan(
        name: name,
        course: try sampleCourse(),
        startTime: Date(timeIntervalSince1970: 1_750_000_000),
        pacing: .steady(secondsPerKilometer: 300)
    )
}

@Suite struct GRDBPlanStoreTests {
    func makeStore() throws -> GRDBPlanStore {
        GRDBPlanStore(database: try AppDatabase.inMemory())
    }

    @Test func savesAndFetchesRoundTrip() async throws {
        let store = try makeStore()
        let plan = try samplePlan()
        try await store.save(plan)
        let all = try await store.fetchAll()
        #expect(all == [plan])
        let fetched = try await store.fetch(id: plan.id)
        #expect(fetched == plan)
    }

    @Test func editingPersists() async throws {
        let store = try makeStore()
        var plan = try samplePlan()
        try await store.save(plan)
        plan.name = "Rotterdam 2027"
        plan.startTime = plan.startTime.addingTimeInterval(3_600)
        plan.pacing = .splits([
            .init(distance: 5_000, secondsPerKilometer: 310),
            .init(distance: 5_000, secondsPerKilometer: 290)
        ])
        try await store.save(plan)
        let all = try await store.fetchAll()
        #expect(all.count == 1)
        #expect(all.first == plan)
    }

    @Test func deleteRemoves() async throws {
        let store = try makeStore()
        let plan = try samplePlan()
        try await store.save(plan)
        try await store.delete(id: plan.id)
        let all = try await store.fetchAll()
        #expect(all.isEmpty)
        let fetched = try await store.fetch(id: plan.id)
        #expect(fetched == nil)
    }

    @Test func duplicateCreatesDistinctCopy() async throws {
        let store = try makeStore()
        let plan = try samplePlan()
        try await store.save(plan)
        let copy = try await store.duplicate(id: plan.id)
        #expect(copy.id != plan.id)
        #expect(copy.name == "Rotterdam copy")
        #expect(copy.course == plan.course)
        #expect(copy.pacing == plan.pacing)
        let all = try await store.fetchAll()
        #expect(all.count == 2)
        #expect(all.contains(plan))
    }

    @Test func duplicateMissingPlanThrows() async throws {
        let store = try makeStore()
        let missing = UUID()
        await #expect(throws: PlanStoreError.planNotFound(missing)) {
            try await store.duplicate(id: missing)
        }
    }

    @Test func fetchAllSortsByName() async throws {
        let store = try makeStore()
        try await store.save(try samplePlan(name: "Zurich"))
        try await store.save(try samplePlan(name: "Amsterdam"))
        try await store.save(try samplePlan(name: "Milan"))
        let names = try await store.fetchAll().map(\.name)
        #expect(names == ["Amsterdam", "Milan", "Zurich"])
    }

    @Test func dataSurvivesReopeningTheDatabase() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("cheerplan-test-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: url) }

        let plan = try samplePlan()
        do {
            let store = GRDBPlanStore(database: try AppDatabase(GRDB.DatabaseQueue(path: url.path)))
            try await store.save(plan)
        }
        // Reopen: migration must be idempotent and the plan still there.
        let reopened = GRDBPlanStore(database: try AppDatabase(GRDB.DatabaseQueue(path: url.path)))
        let all = try await reopened.fetchAll()
        #expect(all == [plan])
    }
}

@Suite struct InMemoryPlanStoreTests {
    @Test func crudRoundTrip() async throws {
        let store = InMemoryPlanStore()
        let plan = try samplePlan()
        try await store.save(plan)
        #expect(try await store.fetchAll() == [plan])
        #expect(try await store.fetch(id: plan.id) == plan)

        let copy = try await store.duplicate(id: plan.id)
        #expect(copy.name == "Rotterdam copy")
        #expect(try await store.fetchAll().count == 2)

        try await store.delete(id: plan.id)
        try await store.delete(id: copy.id)
        #expect(try await store.fetchAll().isEmpty)
    }

    @Test func duplicateMissingPlanThrows() async {
        let store = InMemoryPlanStore()
        let missing = UUID()
        await #expect(throws: PlanStoreError.planNotFound(missing)) {
            try await store.duplicate(id: missing)
        }
    }

    @Test func seededPlansAreVisible() async throws {
        let plan = try samplePlan()
        let store = InMemoryPlanStore(plans: [plan])
        #expect(try await store.fetchAll() == [plan])
    }
}
