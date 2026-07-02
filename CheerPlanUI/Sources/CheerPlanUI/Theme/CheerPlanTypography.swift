import SwiftUI

/// Glanceable type scale — race-day screens are read while jogging in a crowd
/// (spec §6.2): one primary number, one primary instruction, huge type.
public enum CheerPlanTypography {
    /// The one primary number on a race-day screen (countdowns).
    public static let heroNumber = Font.system(size: 64, weight: .bold, design: .rounded).monospacedDigit()
    /// The one primary instruction ("Leave now — 12 min walk NE to Spot 3").
    public static let instruction = Font.system(.title2, design: .rounded).weight(.semibold)
    public static let statValue = Font.system(.title3, design: .rounded).weight(.semibold).monospacedDigit()
    public static let statLabel = Font.system(.caption, design: .rounded).weight(.medium)
}
