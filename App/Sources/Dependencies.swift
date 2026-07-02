import CheerPlanCore
import CheerPlanData
import Foundation

/// Constructor-injected services (spec §5): protocol-typed, no singletons,
/// previews and tests swap in fakes.
struct Dependencies: Sendable {
    let planStore: any PlanStore
    let supporterPlanStore: any SupporterPlanStore
    let raceSessionStore: any RaceSessionStore
    let travelTimeProvider: any TravelTimeProvider
    /// Non-nil when persistent storage could not be opened and an in-memory
    /// fallback is in use — surfaced in the UI, never swallowed.
    let startupError: String?

    static func live() -> Dependencies {
        do {
            let database = try AppDatabase.onDisk()
            // Real MapKit routing, heuristic fallback when it fails, results
            // cached on disk (spec §5) so race day works offline once planned.
            let routing = CachedTravelTimeProvider(
                wrapping: FallbackTravelTimeProvider(primary: MapKitTravelTimeProvider()),
                database: database
            )
            return Dependencies(
                planStore: GRDBPlanStore(database: database),
                supporterPlanStore: GRDBSupporterPlanStore(database: database),
                raceSessionStore: GRDBRaceSessionStore(database: database),
                travelTimeProvider: routing,
                startupError: nil
            )
        } catch {
            return Dependencies(
                planStore: InMemoryPlanStore(),
                supporterPlanStore: InMemorySupporterPlanStore(),
                raceSessionStore: InMemoryRaceSessionStore(),
                travelTimeProvider: FallbackTravelTimeProvider(primary: MapKitTravelTimeProvider()),
                startupError: "Couldn't open the plan database (\(error.localizedDescription)). "
                    + "You can keep working, but changes won't be saved. Restart the app to try again."
            )
        }
    }

    static func preview() -> Dependencies {
        Dependencies(
            planStore: InMemoryPlanStore(plans: [PreviewData.plan]),
            supporterPlanStore: InMemorySupporterPlanStore(),
            raceSessionStore: InMemoryRaceSessionStore(),
            travelTimeProvider: HeuristicTravelEstimator(),
            startupError: nil
        )
    }
}
