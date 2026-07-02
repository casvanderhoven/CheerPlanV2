import Foundation
import Testing
@testable import CheerPlanCore

enum FixtureError: Error {
    case missing(String)
}

enum Fixtures {
    static func data(_ name: String) throws -> Data {
        guard let url = Bundle.module.url(forResource: name, withExtension: "gpx", subdirectory: "Fixtures") else {
            throw FixtureError.missing(name)
        }
        return try Data(contentsOf: url)
    }

    static func course(_ name: String) throws -> Course {
        try GPXParser.parseCourse(from: data(name))
    }
}

/// Deterministic race start: 2025-06-15 15:06:40 UTC. Tests never touch the wall clock.
let raceStart = Date(timeIntervalSince1970: 1_750_000_000)

func approx(_ value: Double, _ expected: Double, tolerance: Double) -> Bool {
    abs(value - expected) <= tolerance
}

func approx(_ value: Date, _ expected: Date, tolerance: TimeInterval) -> Bool {
    abs(value.timeIntervalSince(expected)) <= tolerance
}

/// A synthetic course heading due north: `segments` legs of exactly `spacing` meters.
func straightNorthCourse(segments: Int = 10, spacing: Double = 1000) throws -> Course {
    let origin = Coordinate(latitude: 52.0, longitude: 4.0)
    var coordinates: [(coordinate: Coordinate, elevation: Double?)] = []
    for index in 0...segments {
        let latitude = origin.latitude + Double(index) * spacing / GeoMath.earthRadius * 180 / .pi
        coordinates.append((Coordinate(latitude: latitude, longitude: origin.longitude), nil))
    }
    return try Course(name: "Straight North", coordinates: coordinates)
}

func steadyPlan(
    course: Course,
    secondsPerKilometer: Double = 300,
    startTime: Date = raceStart,
    name: String = "Test Runner"
) -> RunnerPlan {
    RunnerPlan(name: name, course: course, startTime: startTime, pacing: .steady(secondsPerKilometer: secondsPerKilometer))
}
