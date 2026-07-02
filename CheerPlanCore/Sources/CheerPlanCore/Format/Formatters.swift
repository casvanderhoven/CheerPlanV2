import Foundation

/// The single formatting utility — v1 duplicated these helpers 3–4×.
///
/// Everything here is pure string building over SI values (meters, seconds), with
/// km/mi unit support. Locale-sensitive presentation (and the statically cached
/// `DateFormatter`s it needs) belongs to `CheerPlanUI`; the engine stays
/// locale-independent so tests are deterministic.
public enum Formatters {
    /// "1 h 42 min", "21 min", "45 s"
    public static func duration(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded())
        let sign = total < 0 ? "-" : ""
        let magnitude = abs(total)
        let hours = magnitude / 3600
        let minutes = (magnitude % 3600) / 60
        if hours > 0 {
            return minutes > 0 ? "\(sign)\(hours) h \(minutes) min" : "\(sign)\(hours) h"
        }
        if magnitude >= 60 {
            return "\(sign)\(minutes) min"
        }
        return "\(sign)\(magnitude) s"
    }

    /// Race-day countdown: "42:05", or "1:02:09" above the hour. Never negative.
    public static func countdown(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return "\(hours):\(padded(minutes)):\(padded(seconds))"
        }
        return "\(minutes):\(padded(seconds))"
    }

    /// "14.5 km" / "9.0 mi"
    public static func distance(_ meters: Double, unit: DistanceUnit = .kilometers) -> String {
        let value = meters / unit.length
        return String(format: "%.1f", value) + " " + unit.abbreviation
    }

    /// "5:41 /km" from seconds per kilometer.
    public static func pace(secondsPerKilometer: Double, unit: DistanceUnit = .kilometers) -> String {
        let secondsPerUnit = secondsPerKilometer / 1000 * unit.length
        let total = max(0, Int(secondsPerUnit.rounded()))
        return "\(total / 60):\(padded(total % 60)) /" + unit.abbreviation
    }

    /// Wall-clock "10:42" (24-hour). Time zone injectable so tests are deterministic.
    public static func clockTime(_ date: Date, timeZone: TimeZone = .current) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return "\(components.hour ?? 0):\(padded(components.minute ?? 0))"
    }

    private static func padded(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }
}
