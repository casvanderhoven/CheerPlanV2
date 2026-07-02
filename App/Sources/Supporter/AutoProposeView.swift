import CheerPlanCore
import SwiftUI

/// The killer convenience feature: pick how many sightings you want and how you
/// travel; the engine finds the spots (iconic milestones preferred).
struct AutoProposeView: View {
    let model: SupporterPlanModel
    @Environment(\.dismiss) private var dismiss
    @State private var count = 4
    @State private var mode: TravelMode = .walk

    var body: some View {
        NavigationStack {
            Form {
                Stepper("See the runner \(count)×", value: $count, in: 1...8)
                Picker("Travel by", selection: $mode) {
                    ForEach(TravelMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                if model.plan.spectatorStart == nil {
                    Label(
                        "First set where you start: tap the map away from the course.",
                        systemImage: "info.circle"
                    )
                    .font(.footnote)
                }
                Section {
                    Button("Propose spots", systemImage: "wand.and.stars") {
                        Task {
                            await model.propose(count: count, mode: mode)
                            dismiss()
                        }
                    }
                    .disabled(model.plan.spectatorStart == nil)
                } footer: {
                    Text("Replaces your current spots.")
                }
            }
            .navigationTitle("Auto-propose")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
