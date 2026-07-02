import Foundation

public enum DistanceUnit: String, CaseIterable, Codable, Sendable {
    case kilometers
    case miles

    /// Meters per unit.
    public var length: Double {
        switch self {
        case .kilometers: 1000
        case .miles: 1609.344
        }
    }

    public var abbreviation: String {
        switch self {
        case .kilometers: "km"
        case .miles: "mi"
        }
    }
}
