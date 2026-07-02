import Foundation
import Testing
@testable import CheerPlanCore

@Suite struct GPXParserTests {
    @Test func marathonTrackParses() throws {
        let course = try Fixtures.course("marathon-city")
        #expect(course.points.count == 2001)
        #expect(approx(course.totalDistance, 42_200, tolerance: 100))
        #expect(course.name == "Fixture City Marathon")
        #expect(course.hasElevation)
        #expect(course.elevationGain > 0)
        #expect(!course.isLoop)
        // distances are precomputed and strictly non-decreasing
        for (a, b) in zip(course.points, course.points.dropFirst()) {
            #expect(a.distanceFromStart <= b.distanceFromStart)
        }
    }

    @Test func outAndBackIsALoopWithFullDistance() throws {
        let course = try Fixtures.course("out-and-back-10k")
        #expect(course.points.count == 401)
        #expect(approx(course.totalDistance, 10_000, tolerance: 20))
        #expect(course.isLoop)
    }

    @Test func lappedCriteriumParses() throws {
        let course = try Fixtures.course("criterium-3laps")
        #expect(course.points.count == 301)
        #expect(approx(course.totalDistance, 5_999, tolerance: 20))
        #expect(course.isLoop)
    }

    @Test func sparseRouteVariantParses() throws {
        let course = try Fixtures.course("trail-sparse")
        #expect(course.points.count == 40)
        #expect(approx(course.totalDistance, 7_800, tolerance: 20))
        #expect(!course.hasElevation)
        #expect(course.elevationGain == 0)
        #expect(course.name == "Fixture Sparse Trail")
    }

    @Test func messyFileDedupsAndTolerates() throws {
        let course = try Fixtures.course("messy")
        // 12 raw points, 2 exact consecutive duplicates removed
        #expect(course.points.count == 10)
        #expect(approx(course.totalDistance, 900, tolerance: 5))
        #expect(course.hasElevation)
        #expect(course.name == "Messy Course") // whitespace trimmed
        // the duplicated point kept its first occurrence's elevation
        #expect(course.points[3].elevation == 12.0)
        // odd-indexed points had no <ele>
        #expect(course.points[1].elevation == nil)
    }

    @Test func invalidFileThrowsTypedError() throws {
        let data = try Fixtures.data("invalid")
        #expect(throws: GPXError.self) {
            _ = try GPXParser.parseCourse(from: data)
        }
    }

    @Test func emptyFileThrowsNoTrack() throws {
        let data = try Fixtures.data("empty")
        #expect(throws: GPXError.noTrack) {
            _ = try GPXParser.parseCourse(from: data)
        }
    }

    @Test func singlePointThrowsInsufficientPoints() {
        let gpx = """
        <?xml version="1.0"?>
        <gpx version="1.1"><trk><trkseg>
        <trkpt lat="52.0" lon="4.0"/>
        </trkseg></trk></gpx>
        """
        #expect(throws: GPXError.insufficientPoints(found: 1)) {
            _ = try GPXParser.parseCourse(from: gpx)
        }
    }

    @Test func explicitNameOverridesFileName() throws {
        let course = try GPXParser.parseCourse(from: Fixtures.data("messy"), name: "My Race")
        #expect(course.name == "My Race")
    }

    @Test func pointsMissingCoordinatesAreSkipped() throws {
        let gpx = """
        <?xml version="1.0"?>
        <gpx version="1.1"><trk><trkseg>
        <trkpt lat="52.0" lon="4.0"/>
        <trkpt lat="oops" lon="4.0"/>
        <trkpt lat="52.001" lon="4.0"/>
        </trkseg></trk></gpx>
        """
        let course = try GPXParser.parseCourse(from: gpx)
        #expect(course.points.count == 2)
    }
}
