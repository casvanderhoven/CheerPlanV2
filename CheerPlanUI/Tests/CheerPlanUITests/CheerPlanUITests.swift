import CheerPlanCore
import SwiftUI
import Testing
@testable import CheerPlanUI

@MainActor
@Suite struct ThemeTests {
    @Test func feasibilityColorsAreDistinct() {
        let colors = FeasibilityStatus.allCases.map { CheerPlanColors.color(for: $0) }
        #expect(Set(colors).count == FeasibilityStatus.allCases.count)
    }
}

@MainActor
@Suite struct ElevationSamplingTests {
    func course(pointCount: Int, elevated: Bool) -> Course {
        let points = (0..<pointCount).map { index in
            TrackPoint(
                coordinate: Coordinate(latitude: 52.0 + Double(index) * 0.001, longitude: 4.0),
                elevation: elevated ? 10 + Double(index) : nil,
                distanceFromStart: Double(index) * 100
            )
        }
        return Course(name: "Test", points: points)
    }

    @Test func samplesSpanTheWholeCourse() {
        let course = course(pointCount: 11, elevated: true) // 1 km, elevations 10...20
        let samples = ElevationProfileView.samples(for: course, maxSamples: 50)
        #expect(samples.count == 11)
        #expect(samples.first?.distance == 0)
        #expect(samples.first?.elevation == 10)
        #expect(samples.last?.distance == 1_000)
        #expect(samples.last?.elevation == 20)
    }

    @Test func longCoursesAreCappedAtMaxSamples() {
        let course = course(pointCount: 800, elevated: true)
        let samples = ElevationProfileView.samples(for: course, maxSamples: 200)
        #expect(samples.count == 200)
    }

    @Test func noElevationMeansNoSamples() {
        let course = course(pointCount: 20, elevated: false)
        #expect(ElevationProfileView.samples(for: course).isEmpty)
    }
}
