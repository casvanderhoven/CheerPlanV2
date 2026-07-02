import Foundation

/// Travel time between two locations for one mode.
public struct TravelEstimate: Equatable, Codable, Sendable {
    public var mode: TravelMode
    public var duration: TimeInterval
    /// Route distance in meters, when the router provides one.
    public var distance: Double?
    /// True when produced by the offline heuristic rather than real routing —
    /// the UI must label these as estimates.
    public var isEstimate: Bool

    public init(mode: TravelMode, duration: TimeInterval, distance: Double? = nil, isEstimate: Bool) {
        self.mode = mode
        self.duration = duration
        self.distance = distance
        self.isEstimate = isEstimate
    }
}
