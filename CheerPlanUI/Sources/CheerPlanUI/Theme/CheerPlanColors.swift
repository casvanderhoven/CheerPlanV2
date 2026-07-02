import CheerPlanCore
import SwiftUI

/// Semantic colors — the single source (v1 duplicated the feasibility colors 3–4×).
public enum CheerPlanColors {
    /// The feasibility traffic light.
    public static let ok = Color(red: 0.13, green: 0.69, blue: 0.30)
    public static let tight = Color(red: 0.95, green: 0.61, blue: 0.07)
    public static let notFeasible = Color(red: 0.86, green: 0.20, blue: 0.18)

    /// The course polyline on the map.
    public static let course = Color(red: 0.20, green: 0.45, blue: 0.95)
    /// The elevation profile fill/line.
    public static let elevation = Color(red: 0.55, green: 0.45, blue: 0.30)
    public static let accent = course

    public static func color(for status: FeasibilityStatus) -> Color {
        switch status {
        case .ok: ok
        case .tight: tight
        case .notFeasible: notFeasible
        }
    }
}
