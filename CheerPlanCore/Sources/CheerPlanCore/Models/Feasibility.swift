import Foundation

/// The three-state traffic light users understood instantly in v1.
public enum FeasibilityStatus: String, Codable, Sendable, Comparable, CaseIterable {
    case ok
    case tight
    case notFeasible

    private var severity: Int {
        switch self {
        case .ok: 0
        case .tight: 1
        case .notFeasible: 2
        }
    }

    public static func < (lhs: FeasibilityStatus, rhs: FeasibilityStatus) -> Bool {
        lhs.severity < rhs.severity
    }
}

/// The verdict for one travel leg, with the numbers that justify it
/// (surfaced by the UI's progressive-disclosure layer).
public struct FeasibilityVerdict: Hashable, Codable, Sendable {
    public var status: FeasibilityStatus
    /// Spare seconds between spectator arrival and runner arrival. Negative = shortfall.
    public var buffer: TimeInterval
    /// Buffer needed for a comfortable OK: max(2 min, 10% of travel) + mode arrival buffer.
    public var requiredBuffer: TimeInterval

    public init(status: FeasibilityStatus, buffer: TimeInterval, requiredBuffer: TimeInterval) {
        self.status = status
        self.buffer = buffer
        self.requiredBuffer = requiredBuffer
    }
}
