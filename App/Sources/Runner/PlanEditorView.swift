import CheerPlanCore
import CheerPlanUI
import SwiftUI

/// Rename the plan, set the start time, choose pacing. Edits a draft;
/// nothing persists until Save.
struct PlanEditorView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var draft: RunnerPlan

    init(plan: RunnerPlan) {
        _draft = State(initialValue: plan)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Race") {
                    TextField("Plan name", text: $draft.name)
                    DatePicker("Start time", selection: $draft.startTime)
                }
                Section("Pacing") {
                    PacingEditorView(pacing: $draft.pacing, courseDistance: draft.course.totalDistance)
                }
                Section {
                    LabeledContent("Planned finish") {
                        Text(LocalizedFormatters.dayAndTime(draft.plannedFinish))
                    }
                }
            }
            .navigationTitle("Edit plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await appState.save(draft)
                            dismiss()
                        }
                    }
                    .disabled(draft.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

#Preview {
    PlanEditorView(plan: PreviewData.plan)
        .environment(AppState(dependencies: .preview()))
}
