import Foundation
import Testing
@testable import CheerPlanCore

@Suite struct FormattersTests {
    @Test func durations() {
        #expect(Formatters.duration(6_120) == "1 h 42 min")
        #expect(Formatters.duration(3_600) == "1 h")
        #expect(Formatters.duration(1_260) == "21 min")
        #expect(Formatters.duration(59) == "59 s")
        #expect(Formatters.duration(0) == "0 s")
        #expect(Formatters.duration(-90) == "-1 min")
    }

    @Test func countdowns() {
        #expect(Formatters.countdown(3_725) == "1:02:05")
        #expect(Formatters.countdown(125) == "2:05")
        #expect(Formatters.countdown(5) == "0:05")
        #expect(Formatters.countdown(-10) == "0:00") // never negative on race day
    }

    @Test func distancesInBothUnits() {
        #expect(Formatters.distance(14_500) == "14.5 km")
        #expect(Formatters.distance(14_500, unit: .miles) == "9.0 mi")
        #expect(Formatters.distance(0) == "0.0 km")
    }

    @Test func pacesInBothUnits() {
        #expect(Formatters.pace(secondsPerKilometer: 341) == "5:41 /km")
        #expect(Formatters.pace(secondsPerKilometer: 341, unit: .miles) == "9:09 /mi")
        #expect(Formatters.pace(secondsPerKilometer: 300) == "5:00 /km")
    }

    @Test func clockTimeIsTimeZoneAware() throws {
        let utc = try #require(TimeZone(identifier: "UTC"))
        // raceStart is 2025-06-15 15:06:40 UTC
        #expect(Formatters.clockTime(raceStart, timeZone: utc) == "15:06")
        let amsterdam = try #require(TimeZone(identifier: "Europe/Amsterdam"))
        #expect(Formatters.clockTime(raceStart, timeZone: amsterdam) == "17:06") // CEST
    }
}
