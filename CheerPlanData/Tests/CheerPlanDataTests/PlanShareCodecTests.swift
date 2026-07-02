import CheerPlanCore
import Foundation
import Testing
@testable import CheerPlanData

/// A realistic 42.2 km meandering course (same shape as the Core test fixture:
/// 2001 points, 21.1 m steps, slowly drifting heading, undulating elevation).
func syntheticMarathon() throws -> Course {
    var coordinates: [(coordinate: Coordinate, elevation: Double?)] = []
    var latitude = 52.37
    var longitude = 4.90
    let earth = 6_371_000.0
    for index in 0...2_000 {
        let elevation = 10 + 20 * sin(Double(index) / 100) + 5 * sin(Double(index) / 17)
        coordinates.append((Coordinate(latitude: latitude, longitude: longitude), elevation))
        let heading = (45 + 30 * sin(Double(index) / 150)) * Double.pi / 180
        latitude += 21.1 * cos(heading) / earth * 180 / .pi
        longitude += 21.1 * sin(heading) / (earth * cos(latitude * .pi / 180)) * 180 / .pi
    }
    return try Course(name: "Synthetic Marathon", coordinates: coordinates)
}

@Suite struct PlanShareCodecTests {
    func marathonPlan() throws -> RunnerPlan {
        RunnerPlan(
            name: "Amsterdam 2026",
            course: try syntheticMarathon(),
            startTime: Date(timeIntervalSince1970: 1_750_000_000),
            pacing: .splits([
                .init(distance: 21_097.5, secondsPerKilometer: 310),
                .init(distance: 21_097.5, secondsPerKilometer: 290)
            ])
        )
    }

    @Test func linkRoundTripsTheWholePlan() throws {
        let plan = try marathonPlan()
        let url = try PlanShareCodec.shareURL(for: plan)

        // fits comfortably in a URL
        #expect(url.absoluteString.count < 8_000)
        #expect(url.host() == PlanShareCodec.linkHost)

        let decoded = try PlanShareCodec.decodePlan(from: url)
        #expect(decoded.id == plan.id)
        #expect(decoded.name == plan.name)
        #expect(decoded.startTime == plan.startTime)
        #expect(decoded.pacing == plan.pacing)
        #expect(decoded.course.name == plan.course.name)
        #expect(decoded.course.hasElevation)
        // simplified course: much smaller, nearly the same length
        #expect(decoded.course.points.count < plan.course.points.count / 3)
        let lengthError = abs(decoded.course.totalDistance - plan.course.totalDistance)
        #expect(lengthError < plan.course.totalDistance * 0.01)
    }

    @Test func customSchemeLinksDecodeToo() throws {
        let plan = try marathonPlan()
        let https = try PlanShareCodec.shareURL(for: plan)
        let custom = try #require(URL(string: "cheerplan://plan#\(https.fragment(percentEncoded: false) ?? "")"))
        let decoded = try PlanShareCodec.decodePlan(from: custom)
        #expect(decoded.id == plan.id)
    }

    @Test func foreignAndBrokenLinksThrowTypedErrors() throws {
        let somewhereElse = try #require(URL(string: "https://example.com/p#v1.abc"))
        #expect(throws: ShareCodecError.notAShareLink) {
            _ = try PlanShareCodec.decodePlan(from: somewhereElse)
        }
        let noFragment = try #require(URL(string: "https://cheerplan.app/p"))
        #expect(throws: ShareCodecError.malformedPayload) {
            _ = try PlanShareCodec.decodePlan(from: noFragment)
        }
        let futureVersion = try #require(URL(string: "https://cheerplan.app/p#v9.abc"))
        #expect(throws: ShareCodecError.unsupportedVersion("v9")) {
            _ = try PlanShareCodec.decodePlan(from: futureVersion)
        }
        let garbage = try #require(URL(string: "https://cheerplan.app/p#v1.!!!"))
        #expect(throws: ShareCodecError.malformedPayload) {
            _ = try PlanShareCodec.decodePlan(from: garbage)
        }
    }

    @Test func fileRoundTripsAtFullFidelity() throws {
        let plan = try marathonPlan()
        let data = try PlanShareCodec.fileData(for: plan)
        let decoded = try PlanShareCodec.decodePlan(fromFileData: data)
        #expect(decoded == plan)
    }

    @Test func fileWithUnknownVersionThrows() throws {
        let plan = try samplePlan()
        var object = try #require(
            try JSONSerialization.jsonObject(with: PlanShareCodec.fileData(for: plan)) as? [String: Any]
        )
        object["version"] = 99
        let data = try JSONSerialization.data(withJSONObject: object)
        #expect(throws: ShareCodecError.unsupportedVersion("99")) {
            _ = try PlanShareCodec.decodePlan(fromFileData: data)
        }
    }

    @Test func garbageFileDataThrows() {
        #expect(throws: ShareCodecError.malformedPayload) {
            _ = try PlanShareCodec.decodePlan(fromFileData: Data("not a plan".utf8))
        }
    }

    @Test func base64URLIsURLSafeAndReversible() {
        let data = Data((0...255).map { UInt8($0) })
        let encoded = PlanShareCodec.base64URLEncode(data)
        #expect(!encoded.contains("+"))
        #expect(!encoded.contains("/"))
        #expect(!encoded.contains("="))
        #expect(PlanShareCodec.base64URLDecode(encoded) == data)
    }
}
