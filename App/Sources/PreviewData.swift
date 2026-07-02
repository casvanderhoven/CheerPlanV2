import CheerPlanCore
import Foundation

/// Deterministic sample data for previews.
enum PreviewData {
    static let course: Course = {
        let points = (0...42).map { index in
            TrackPoint(
                coordinate: Coordinate(
                    latitude: 52.37 + Double(index) * 0.006,
                    longitude: 4.90 + Double(index % 7) * 0.004
                ),
                elevation: 8 + 25 * sin(Double(index) / 5),
                distanceFromStart: Double(index) * 1_000
            )
        }
        return Course(name: "Preview Marathon", points: points)
    }()

    static let plan = RunnerPlan(
        name: "Preview Marathon",
        course: course,
        startTime: Date(timeIntervalSince1970: 1_750_000_000),
        pacing: .steady(secondsPerKilometer: 330)
    )
}
