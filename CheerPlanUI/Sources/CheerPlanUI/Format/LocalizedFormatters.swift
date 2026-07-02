import CheerPlanCore
import Foundation

/// Locale-aware presentation formatting for the UI layer.
///
/// `DateFormatter`s are created once and cached (v1 lesson: never per render);
/// main-actor confined, which is where view code formats. Locale-independent
/// engine formatting (durations, paces, distances) stays in Core's `Formatters`.
@MainActor
public enum LocalizedFormatters {
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    private static let dayTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    /// "10:42" / "10:42 AM" per locale.
    public static func time(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }

    /// "Jun 15, 2025 at 10:42" per locale.
    public static func dayAndTime(_ date: Date) -> String {
        dayTimeFormatter.string(from: date)
    }
}
