import Foundation

/// The supporter's persistent document: where they start race day, which spots
/// they plan to watch from, and when they can leave.
///
/// The timed, verdict-carrying itinerary is always *computed* from this via
/// `FeasibilityEngine.evaluate` — one source of truth, nothing cached that can
/// go stale when the runner plan changes.
public struct SupporterPlan: Identifiable, Equatable, Codable, Sendable {
    public let id: UUID
    /// The runner plan this supporter is following.
    public var runnerPlanID: UUID
    /// Where the supporter starts (home, hotel). Nil until they pick it.
    public var spectatorStart: Coordinate?
    /// When they can leave that start. Nil means the race start.
    public var earliestDeparture: Date?
    public var spots: [PlannedSpot]

    public init(
        id: UUID = UUID(),
        runnerPlanID: UUID,
        spectatorStart: Coordinate? = nil,
        earliestDeparture: Date? = nil,
        spots: [PlannedSpot] = []
    ) {
        self.id = id
        self.runnerPlanID = runnerPlanID
        self.spectatorStart = spectatorStart
        self.earliestDeparture = earliestDeparture
        self.spots = spots
    }
}
