import CheerPlanCore
import CheerPlanData
import Foundation

/// Constructor-injected services (spec §5): protocol-typed, no singletons,
/// previews and tests swap in fakes.
struct Dependencies: Sendable {
    let planStore: any PlanStore
    let travelTimeProvider: any TravelTimeProvider
    /// Non-nil when persistent storage could not be opened and an in-memory
    /// fallback is in use — surfaced in the UI, never swallowed.
    let startupError: String?

    static func live() -> Dependencies {
        do {
            let database = try AppDatabase.onDisk()
            return Dependencies(
                planStore: GRDBPlanStore(database: database),
                travelTimeProvider: HeuristicTravelEstimator(),
                startupError: nil
            )
        } catch {
            return Dependencies(
                planStore: InMemoryPlanStore(),
                travelTimeProvider: HeuristicTravelEstimator(),
                startupError: "Couldn't open the plan database (\(error.localizedDescription)). "
                    + "You can keep working, but changes won't be saved. Restart the app to try again."
            )
        }
    }

    static func preview() -> Dependencies {
        Dependencies(
            planStore: InMemoryPlanStore(plans: [PreviewData.plan]),
            travelTimeProvider: HeuristicTravelEstimator(),
            startupError: nil
        )
    }
}
