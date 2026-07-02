import Foundation

/// Generates the distances spectators plan around: every km/mile marker plus the
/// culturally meaningful ones — 5K, 10K, half (21.0975 km), 30K ("the wall"), 40K,
/// finish — scaled to the course distance.
public enum MilestoneGenerator {
    /// How close (meters) a plain marker may sit to an iconic milestone before it is dropped.
    static let markerSuppressionRadius: Double = 100
    /// Iconic milestones closer to the finish than this are dropped — the finish covers them.
    static let finishSuppressionRadius: Double = 200

    public static func milestones(
        for courseDistance: Double,
        unit: DistanceUnit = .kilometers
    ) -> [Milestone] {
        guard courseDistance > 0 else { return [] }

        let iconicCandidates: [(kind: Milestone.Kind, distance: Double, label: String)] = [
            (.fiveK, 5_000, "5K"),
            (.tenK, 10_000, "10K"),
            (.half, 21_097.5, "Half marathon"),
            (.thirtyK, 30_000, "30K — the wall"),
            (.fortyK, 40_000, "40K")
        ]

        var milestones: [Milestone] = iconicCandidates
            .filter { $0.distance <= courseDistance - Self.finishSuppressionRadius }
            .map { Milestone(kind: $0.kind, distance: $0.distance, label: $0.label) }
        milestones.append(Milestone(kind: .finish, distance: courseDistance, label: "Finish"))

        var number = 1
        while Double(number) * unit.length <= courseDistance - Self.markerSuppressionRadius {
            let distance = Double(number) * unit.length
            let nearIconic = milestones.contains { abs($0.distance - distance) < Self.markerSuppressionRadius }
            if !nearIconic {
                let prefix = unit == .kilometers ? "km" : "mile"
                milestones.append(
                    Milestone(
                        kind: .marker(number: number, unit: unit),
                        distance: distance,
                        label: "\(prefix) \(number)"
                    )
                )
            }
            number += 1
        }

        return milestones.sorted { $0.distance < $1.distance }
    }
}
