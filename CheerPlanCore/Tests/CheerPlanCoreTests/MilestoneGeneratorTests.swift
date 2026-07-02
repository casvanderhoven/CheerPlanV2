import Foundation
import Testing
@testable import CheerPlanCore

@Suite struct MilestoneGeneratorTests {
    @Test func marathonGetsTheFullIconicSet() {
        let milestones = MilestoneGenerator.milestones(for: 42_195)
        let kinds = milestones.map(\.kind)
        #expect(kinds.contains(.fiveK))
        #expect(kinds.contains(.tenK))
        #expect(kinds.contains(.half))
        #expect(kinds.contains(.thirtyK))
        #expect(kinds.contains(.fortyK))
        #expect(kinds.contains(.finish))
        #expect(milestones.last?.distance == 42_195)

        // plain markers are suppressed where an iconic milestone stands
        let markerNumbers = milestones.compactMap { milestone -> Int? in
            if case .marker(let number, _) = milestone.kind { return number }
            return nil
        }
        #expect(!markerNumbers.contains(5))
        #expect(!markerNumbers.contains(10))
        #expect(!markerNumbers.contains(21)) // km 21 is 97.5 m from the half — dropped
        #expect(!markerNumbers.contains(30))
        #expect(!markerNumbers.contains(40))
        #expect(markerNumbers.contains(1))
        #expect(markerNumbers.contains(42)) // 195 m before the finish — kept

        let distances = milestones.map(\.distance)
        #expect(distances == distances.sorted())
    }

    @Test func shortCourseScalesDown() {
        let milestones = MilestoneGenerator.milestones(for: 10_000)
        let kinds = milestones.map(\.kind)
        #expect(kinds.contains(.fiveK))
        #expect(!kinds.contains(.tenK)) // the finish covers it
        #expect(!kinds.contains(.half))
        #expect(milestones.last?.distance == 10_000)
        let markerNumbers = milestones.compactMap { milestone -> Int? in
            if case .marker(let number, _) = milestone.kind { return number }
            return nil
        }
        #expect(markerNumbers == [1, 2, 3, 4, 6, 7, 8, 9])
    }

    @Test func mileMarkersUseTheMileGrid() {
        let milestones = MilestoneGenerator.milestones(for: 10_000, unit: .miles)
        let markers = milestones.filter {
            if case .marker = $0.kind { return true }
            return false
        }
        #expect(markers.count == 6) // miles 1–6 fit in 10 km
        #expect(markers.first?.label == "mile 1")
        #expect(approx(markers[0].distance, 1_609.344, tolerance: 0.001))
    }

    @Test func iconicFlag() {
        let milestones = MilestoneGenerator.milestones(for: 42_195)
        let half = milestones.first { $0.kind == .half }
        let km1 = milestones.first { $0.kind == .marker(number: 1, unit: .kilometers) }
        #expect(half?.isIconic == true)
        #expect(km1?.isIconic == false)
    }

    @Test func zeroCourseHasNoMilestones() {
        #expect(MilestoneGenerator.milestones(for: 0).isEmpty)
    }
}
