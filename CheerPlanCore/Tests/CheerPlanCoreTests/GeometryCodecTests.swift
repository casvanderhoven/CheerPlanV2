import Foundation
import Testing
@testable import CheerPlanCore

@Suite struct PolylineCodecTests {
    @Test func matchesTheCanonicalGoogleExample() throws {
        let coordinates = [
            Coordinate(latitude: 38.5, longitude: -120.2),
            Coordinate(latitude: 40.7, longitude: -120.95),
            Coordinate(latitude: 43.252, longitude: -126.453)
        ]
        #expect(PolylineCodec.encode(coordinates) == "_p~iF~ps|U_ulLnnqC_mqNvxq`@")

        let decoded = try #require(PolylineCodec.decode("_p~iF~ps|U_ulLnnqC_mqNvxq`@"))
        #expect(decoded.count == 3)
        for (original, roundTripped) in zip(coordinates, decoded) {
            #expect(approx(roundTripped.latitude, original.latitude, tolerance: 1e-5))
            #expect(approx(roundTripped.longitude, original.longitude, tolerance: 1e-5))
        }
    }

    @Test func roundTripsWithinPrecision() throws {
        let coordinates = [
            Coordinate(latitude: 0, longitude: 0),
            Coordinate(latitude: -52.123456, longitude: 4.987654),
            Coordinate(latitude: 52.370216, longitude: 4.895168),
            Coordinate(latitude: 52.370301, longitude: 4.895099),
            Coordinate(latitude: -89.999, longitude: 179.999)
        ]
        let decoded = try #require(PolylineCodec.decode(PolylineCodec.encode(coordinates)))
        #expect(decoded.count == coordinates.count)
        for (original, roundTripped) in zip(coordinates, decoded) {
            #expect(approx(roundTripped.latitude, original.latitude, tolerance: 6e-6))
            #expect(approx(roundTripped.longitude, original.longitude, tolerance: 6e-6))
        }
    }

    @Test func emptyAndMalformedInputs() {
        #expect(PolylineCodec.encode([]) == "")
        #expect(PolylineCodec.decode("") == [])
        // truncated: a latitude with no longitude
        #expect(PolylineCodec.decode("_p~iF") == nil)
        // character outside the polyline alphabet
        #expect(PolylineCodec.decode("_p~iF~ps|U\u{19}") == nil)
    }

    @Test func marathonEncodesCompactly() throws {
        let course = try Fixtures.course("marathon-city")
        let simplified = CourseSimplifier.simplify(course.points.map(\.coordinate), tolerance: 15)
        let encoded = PolylineCodec.encode(simplified)
        #expect(encoded.utf8.count < 6_000) // fits a URL with lots of headroom
        let decoded = try #require(PolylineCodec.decode(encoded))
        #expect(decoded.count == simplified.count)
    }
}

@Suite struct CourseSimplifierTests {
    @Test func collinearPointsCollapseToEndpoints() throws {
        let course = try straightNorthCourse(segments: 100, spacing: 100)
        let simplified = CourseSimplifier.simplify(course.points.map(\.coordinate), tolerance: 5)
        #expect(simplified.count == 2)
        #expect(simplified.first == course.points.first?.coordinate)
        #expect(simplified.last == course.points.last?.coordinate)
    }

    @Test func significantCornersSurvive() {
        let a = Coordinate(latitude: 52.0, longitude: 4.0)
        let corner = Coordinate(latitude: 52.0045, longitude: 4.0015) // ~100 m east of the line
        let b = Coordinate(latitude: 52.009, longitude: 4.0)
        let simplified = CourseSimplifier.simplify([a, corner, b], tolerance: 10)
        #expect(simplified == [a, corner, b])
    }

    @Test func marathonSimplifiesHardWithBoundedError() throws {
        let course = try Fixtures.course("marathon-city")
        let coordinates = course.points.map(\.coordinate)
        let tolerance = 15.0
        let simplified = CourseSimplifier.simplify(coordinates, tolerance: tolerance)

        #expect(simplified.count > 2)
        #expect(simplified.count < coordinates.count / 3)
        #expect(simplified.first == coordinates.first)
        #expect(simplified.last == coordinates.last)

        // Every original point stays within tolerance (plus numeric slack)
        // of the simplified polyline.
        let simplifiedCourse = try Course(
            name: "simplified",
            coordinates: simplified.map { (coordinate: $0, elevation: nil) }
        )
        let geometry = CourseGeometry(course: simplifiedCourse)
        var worst = 0.0
        for coordinate in coordinates {
            if let snap = geometry.snap(coordinate) {
                worst = max(worst, snap.offRouteDistance)
            }
        }
        #expect(worst <= tolerance * 1.2)
    }

    @Test func tinyInputsPassThrough() {
        let two = [Coordinate(latitude: 1, longitude: 1), Coordinate(latitude: 2, longitude: 2)]
        #expect(CourseSimplifier.simplify(two, tolerance: 10) == two)
        #expect(CourseSimplifier.simplify([], tolerance: 10).isEmpty)
    }
}

@Suite struct SupporterPlanTests {
    @Test func roundTripsThroughJSON() throws {
        let course = try straightNorthCourse()
        let geometry = CourseGeometry(course: course)
        let plan = SupporterPlan(
            runnerPlanID: UUID(),
            spectatorStart: Coordinate(latitude: 52.001, longitude: 4.002),
            earliestDeparture: raceStart.addingTimeInterval(-1_800),
            spots: [
                PlannedSpot(meetPoint: geometry.meetPoint(atDistance: 2_000), travelMode: .walk),
                PlannedSpot(meetPoint: geometry.meetPoint(atDistance: 6_000), travelMode: .transit)
            ]
        )
        let decoded = try JSONDecoder().decode(SupporterPlan.self, from: JSONEncoder().encode(plan))
        #expect(decoded == plan)
    }
}
