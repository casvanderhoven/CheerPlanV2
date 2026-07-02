import Foundation

/// A course bound to a start time and a pacing strategy — the runner's side of the product.
public struct RunnerPlan: Identifiable, Equatable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var course: Course
    public var startTime: Date
    public var pacing: PacingStrategy

    public init(id: UUID = UUID(), name: String, course: Course, startTime: Date, pacing: PacingStrategy) {
        self.id = id
        self.name = name
        self.course = course
        self.startTime = startTime
        self.pacing = pacing
    }

    /// The position⇄time bijection for this plan. Cheap to build; cache per evaluation loop.
    public func paceModel() -> PaceModel {
        PaceModel(pacing: pacing, courseDistance: course.totalDistance)
    }

    /// When the runner reaches `distance` meters from the start, per plan.
    public func arrivalTime(atDistance distance: Double) -> Date {
        startTime.addingTimeInterval(paceModel().time(atDistance: distance))
    }

    public var plannedFinish: Date {
        startTime.addingTimeInterval(paceModel().totalDuration)
    }
}
