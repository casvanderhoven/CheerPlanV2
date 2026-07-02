import Foundation

/// A culturally meaningful course distance: every km/mile marker plus the icons.
public struct Milestone: Equatable, Codable, Sendable {
    public enum Kind: Equatable, Codable, Sendable {
        /// A plain distance marker: km 7, mile 12, ...
        case marker(number: Int, unit: DistanceUnit)
        case fiveK
        case tenK
        case half
        case thirtyK
        case fortyK
        case finish
    }

    public var kind: Kind
    /// Meters from the course start.
    public var distance: Double
    public var label: String

    public init(kind: Kind, distance: Double, label: String) {
        self.kind = kind
        self.distance = distance
        self.label = label
    }

    /// True for the milestones spectators plan around (5K, half, the wall, finish...).
    public var isIconic: Bool {
        if case .marker = kind { return false }
        return true
    }
}
