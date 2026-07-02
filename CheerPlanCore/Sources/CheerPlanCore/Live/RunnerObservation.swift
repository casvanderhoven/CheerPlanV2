import Foundation

/// One report of the runner's position on the course.
public struct RunnerObservation: Equatable, Codable, Sendable {
    public enum Source: String, CaseIterable, Codable, Sendable {
        /// Supporter tapped "runner passed me" at a known spot.
        case checkIn
        /// Manual correction ("they're at km 25 right now").
        case recalibration
        /// The runner's shared live location, snapped to the course.
        case runnerLocation
        /// An official race-timing feed (mat crossings).
        case timingFeed
    }

    /// Meters from the course start.
    public var courseDistance: Double
    public var timestamp: Date
    public var source: Source

    public init(courseDistance: Double, timestamp: Date, source: Source) {
        self.courseDistance = courseDistance
        self.timestamp = timestamp
        self.source = source
    }
}

/// The pluggable seam for anything that can report runner positions — check-in
/// buttons, recalibration taps, shared locations, official timing-feed adapters.
/// Implementations live in the app layer; they all funnel into one `ProgressEstimator`.
public protocol PositionSource: Sendable {
    var kind: RunnerObservation.Source { get }
    /// Stream of observations; finishes when the source dries up.
    func observations() -> AsyncStream<RunnerObservation>
}
