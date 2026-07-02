import ActivityKit
import Foundation

/// The race-day Live Activity contract, compiled into both the app and the
/// widget extension. `ContentState` carries display-ready values only, so the
/// extension needs no package dependencies.
struct RaceActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// "5K" or "km 15.2" — where to be next.
        var nextSpotLabel: String
        /// Comfortable departure time; the island counts down to this.
        var leaveBy: Date
        /// When the runner reaches that spot (recalibrated).
        var runnerArrival: Date
        /// True once it's time to move.
        var isGo: Bool
        /// One glanceable instruction line.
        var instruction: String
    }

    var runnerName: String
}
