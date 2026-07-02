import Foundation
import Testing
@testable import CheerPlanCore

@Suite struct CourseGeometryTests {
    @Test func pointAtDistanceInterpolates() throws {
        let course = try straightNorthCourse() // 10 × 1000 m due north
        let geometry = CourseGeometry(course: course)
        let point = geometry.point(atDistance: 1500)
        let expectedLatitude = (course.points[1].coordinate.latitude + course.points[2].coordinate.latitude) / 2
        #expect(approx(point.coordinate.latitude, expectedLatitude, tolerance: 1e-7))
        #expect(point.coordinate.longitude == 4.0)
        #expect(point.distanceFromStart == 1500)
    }

    @Test func pointAtDistanceClampsToCourse() throws {
        let course = try straightNorthCourse()
        let geometry = CourseGeometry(course: course)
        #expect(geometry.point(atDistance: -50).coordinate == course.points[0].coordinate)
        #expect(geometry.point(atDistance: 1e9).coordinate == course.points[10].coordinate)
    }

    @Test func pointAtDistanceInterpolatesElevation() throws {
        let course = try Fixtures.course("marathon-city")
        let geometry = CourseGeometry(course: course)
        let sample = geometry.point(atDistance: 10_000)
        #expect(sample.elevation != nil)
    }

    @Test func snapProjectsOntoSegmentNotNearestRawPoint() throws {
        let course = try Fixtures.course("trail-sparse") // 200 m between points
        let geometry = CourseGeometry(course: course)
        let a = course.points[10]
        let b = course.points[11]
        let mid = GeoMath.interpolate(a.coordinate, b.coordinate, fraction: 0.5)
        // ~30 m east of the middle of a coarse segment
        let query = Coordinate(latitude: mid.latitude, longitude: mid.longitude + 0.0004)
        let snap = try #require(geometry.snap(query))

        // Perpendicular projection keeps us close to the drawn line...
        #expect(snap.offRouteDistance < 40)
        // ...and lands mid-segment, not at a raw track point.
        #expect(approx(snap.courseDistance, a.distanceFromStart + 100, tolerance: 40))
        // Snapping to the nearest raw point would have reported a much larger offset.
        #expect(GeoMath.distance(query, a.coordinate) > snap.offRouteDistance + 50)
        #expect(GeoMath.distance(query, b.coordinate) > snap.offRouteDistance + 50)
    }

    @Test func snapAtCourseEndsClamps() throws {
        let course = try straightNorthCourse()
        let geometry = CourseGeometry(course: course)
        // south of the start: projects onto the very first point
        let below = Coordinate(latitude: 51.99, longitude: 4.0)
        let snap = try #require(geometry.snap(below))
        #expect(snap.courseDistance == 0)
    }

    @Test func outAndBackHasTwoPassBys() throws {
        let course = try Fixtures.course("out-and-back-10k")
        let geometry = CourseGeometry(course: course)
        let spot = course.points[80].coordinate // 2000 m out
        let passes = geometry.passBys(near: spot, within: 75)
        #expect(passes.count == 2)
        #expect(approx(passes[0].courseDistance, 2_000, tolerance: 30))
        #expect(approx(passes[1].courseDistance, 8_000, tolerance: 30))
    }

    @Test func turnaroundIsASinglePass() throws {
        let course = try Fixtures.course("out-and-back-10k")
        let geometry = CourseGeometry(course: course)
        let passes = geometry.passBys(near: course.points[200].coordinate, within: 75)
        #expect(passes.count == 1)
        #expect(approx(passes[0].courseDistance, 5_000, tolerance: 80))
    }

    @Test func lappedCourseHasOnePassPerLap() throws {
        let course = try Fixtures.course("criterium-3laps")
        let geometry = CourseGeometry(course: course)
        let spot = course.points[50].coordinate // halfway around lap 1
        let passes = geometry.passBys(near: spot, within: 60)
        #expect(passes.count == 3)
        let lap = course.totalDistance / 3
        #expect(approx(passes[0].courseDistance, lap * 0.5, tolerance: 30))
        #expect(approx(passes[1].courseDistance, lap * 1.5, tolerance: 30))
        #expect(approx(passes[2].courseDistance, lap * 2.5, tolerance: 30))
    }

    @Test func farAwayLocationHasNoPassBys() throws {
        let course = try straightNorthCourse()
        let geometry = CourseGeometry(course: course)
        let far = Coordinate(latitude: 53.5, longitude: 5.0)
        #expect(geometry.passBys(near: far, within: 75).isEmpty)
    }

    @Test func meetPointSnapsAndClamps() throws {
        let course = try straightNorthCourse()
        let geometry = CourseGeometry(course: course)
        let spot = geometry.meetPoint(atDistance: 2500, name: "Corner")
        #expect(spot.courseDistance == 2500)
        #expect(spot.name == "Corner")
        #expect(approx(spot.coordinate.latitude, geometry.point(atDistance: 2500).coordinate.latitude, tolerance: 1e-9))
        #expect(geometry.meetPoint(atDistance: -10).courseDistance == 0)
        #expect(geometry.meetPoint(atDistance: 1e9).courseDistance == course.totalDistance)
    }
}
