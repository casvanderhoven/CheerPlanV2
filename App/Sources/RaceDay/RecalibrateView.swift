import CheerPlanCore
import SwiftUI

/// "They're at km X right now" — manual recalibration with milestone shortcuts.
struct RecalibrateView: View {
    let model: LiveRaceModel
    @Environment(\.dismiss) private var dismiss
    @State private var distance: Double

    init(model: LiveRaceModel) {
        self.model = model
        _distance = State(initialValue: model.snapshot?.runnerCourseDistance ?? 0)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Where is the runner right now?") {
                    Text(Formatters.distance(distance))
                        .font(.title2.bold().monospacedDigit())
                        .frame(maxWidth: .infinity)
                    Slider(value: $distance, in: 0...model.runnerPlan.course.totalDistance)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(milestones, id: \.distance) { milestone in
                                Button(milestone.label) { distance = milestone.distance }
                                    .buttonStyle(.bordered)
                            }
                        }
                    }
                }
                Button("Runner is here now", systemImage: "scope") {
                    Task {
                        await model.recalibrate(toDistance: distance)
                        dismiss()
                    }
                }
            }
            .navigationTitle("Recalibrate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var milestones: [Milestone] {
        MilestoneGenerator.milestones(for: model.runnerPlan.course.totalDistance)
            .filter(\.isIconic)
    }
}
