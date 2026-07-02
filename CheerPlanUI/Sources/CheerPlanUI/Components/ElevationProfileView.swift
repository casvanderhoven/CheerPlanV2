import Charts
import CheerPlanCore
import SwiftUI

/// The course elevation profile — parsed *and displayed* (v1 parsed it and showed
/// nothing for months). Optional `markedDistances` draw vertical rules where meet
/// points sit (used from M3 on).
public struct ElevationProfileView: View {
    public struct Sample: Identifiable, Equatable {
        public var distance: Double
        public var elevation: Double
        public var id: Double { distance }

        public init(distance: Double, elevation: Double) {
            self.distance = distance
            self.elevation = elevation
        }
    }

    public let markedDistances: [Double]
    public let unit: DistanceUnit
    private let samples: [Sample]

    public init(course: Course, markedDistances: [Double] = [], unit: DistanceUnit = .kilometers) {
        self.markedDistances = markedDistances
        self.unit = unit
        self.samples = Self.samples(for: course)
    }

    public var body: some View {
        if samples.isEmpty {
            ContentUnavailableView(
                "No elevation data",
                systemImage: "chart.xyaxis.line",
                description: Text("This course file has no elevation.")
            )
        } else {
            chart
        }
    }

    private var chart: some View {
        Chart {
            ForEach(samples) { sample in
                AreaMark(
                    x: .value("Distance", sample.distance / unit.length),
                    y: .value("Elevation", sample.elevation)
                )
                .foregroundStyle(CheerPlanColors.elevation.opacity(0.25))
                LineMark(
                    x: .value("Distance", sample.distance / unit.length),
                    y: .value("Elevation", sample.elevation)
                )
                .foregroundStyle(CheerPlanColors.elevation)
            }
            ForEach(markedDistances, id: \.self) { distance in
                RuleMark(x: .value("Spot", distance / unit.length))
                    .foregroundStyle(CheerPlanColors.accent.opacity(0.6))
            }
        }
        .chartXAxisLabel(unit.abbreviation)
        .chartYAxisLabel("m")
        .accessibilityLabel("Elevation profile")
    }

    /// Up to `maxSamples` evenly spaced samples, each a binary-searched
    /// point-at-distance lookup — never a rescan of the raw track.
    /// Pure function; `nonisolated` because `View` conformance would otherwise
    /// pin it to the main actor.
    nonisolated static func samples(for course: Course, maxSamples: Int = 200) -> [Sample] {
        guard course.hasElevation, course.totalDistance > 0 else { return [] }
        let geometry = CourseGeometry(course: course)
        let count = min(maxSamples, max(2, course.points.count))
        var result: [Sample] = []
        result.reserveCapacity(count)
        for index in 0..<count {
            let distance = course.totalDistance * Double(index) / Double(count - 1)
            if let elevation = geometry.point(atDistance: distance).elevation {
                result.append(Sample(distance: distance, elevation: elevation))
            }
        }
        return result
    }
}

#Preview {
    let points = (0...40).map { index in
        TrackPoint(
            coordinate: Coordinate(latitude: 52.0 + Double(index) * 0.002, longitude: 4.0),
            elevation: 12 + 30 * sin(Double(index) / 6),
            distanceFromStart: Double(index) * 500
        )
    }
    return ElevationProfileView(course: Course(name: "Preview", points: points))
        .frame(height: 140)
        .padding()
}
