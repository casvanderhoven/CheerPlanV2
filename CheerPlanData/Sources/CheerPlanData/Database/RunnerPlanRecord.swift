import CheerPlanCore
import Foundation
import GRDB

/// Row mapping for `RunnerPlan`: scalar columns for list queries and sorting,
/// course and pacing as JSON documents.
struct RunnerPlanRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "runnerPlan"

    var id: String
    var name: String
    var startTime: Date
    var courseData: Data
    var pacingData: Data

    init(plan: RunnerPlan) throws {
        let encoder = JSONEncoder()
        id = plan.id.uuidString
        name = plan.name
        startTime = plan.startTime
        courseData = try encoder.encode(plan.course)
        pacingData = try encoder.encode(plan.pacing)
    }

    func plan() throws -> RunnerPlan {
        let decoder = JSONDecoder()
        return RunnerPlan(
            id: UUID(uuidString: id) ?? UUID(),
            name: name,
            course: try decoder.decode(Course.self, from: courseData),
            startTime: startTime,
            pacing: try decoder.decode(PacingStrategy.self, from: pacingData)
        )
    }
}
