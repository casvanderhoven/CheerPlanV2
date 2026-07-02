import ActivityKit
import Foundation

/// Starts, updates, and ends the race-day Live Activity — a primary surface on
/// race day (spec §2.7). Live Activities are an enhancement, not a dependency:
/// when the user has disabled them, race day carries on without comment, so
/// failures here are intentionally quiet.
@MainActor
final class LiveActivityController {
    private var activity: Activity<RaceActivityAttributes>?

    func start(runnerName: String, state: RaceActivityAttributes.ContentState?) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled, let state else { return }
        activity = try? Activity.request(
            attributes: RaceActivityAttributes(runnerName: runnerName),
            content: ActivityContent(state: state, staleDate: nil)
        )
    }

    func update(state: RaceActivityAttributes.ContentState?) async {
        guard let state else { return }
        await activity?.update(ActivityContent(state: state, staleDate: nil))
    }

    func end() async {
        await activity?.end(nil, dismissalPolicy: .immediate)
        activity = nil
    }
}
