import Foundation

/// How the runner intends to pace the race.
public enum PacingStrategy: Equatable, Codable, Sendable {
    /// Same pace for the whole course.
    case steady(secondsPerKilometer: Double)
    /// Ordered splits, each with its own pace (negative/positive splits, fade plans).
    /// If the splits cover less than the course, the final split's pace extends to the finish;
    /// anything beyond the course length is ignored.
    case splits([Split])

    public struct Split: Equatable, Codable, Sendable {
        /// Length of this split in meters.
        public var distance: Double
        public var secondsPerKilometer: Double

        public init(distance: Double, secondsPerKilometer: Double) {
            self.distance = distance
            self.secondsPerKilometer = secondsPerKilometer
        }
    }

    /// Convenience: an even pace that finishes the given distance in the given time.
    public static func targetFinish(courseDistance: Double, duration: TimeInterval) -> PacingStrategy {
        guard courseDistance > 0 else { return .steady(secondsPerKilometer: 0) }
        return .steady(secondsPerKilometer: duration / courseDistance * 1000)
    }
}
