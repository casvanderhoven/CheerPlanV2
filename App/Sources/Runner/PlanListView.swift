import CheerPlanCore
import SwiftUI

/// All runner plans: create, rename (in the editor), duplicate, delete;
/// tapping a plan opens the course map.
struct PlanListView: View {
    @Environment(AppState.self) private var appState
    @State private var showingImport = false
    @State private var planPendingDeletion: RunnerPlan?

    var body: some View {
        content
            .navigationTitle("CheerPlan")
            .navigationDestination(for: UUID.self) { id in
                if let plan = appState.plan(id: id) {
                    CourseDetailView(plan: plan)
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Import course", systemImage: "plus") { showingImport = true }
                }
            }
            .sheet(isPresented: $showingImport) {
                CourseImportView()
            }
            .confirmationDialog(
                "Delete \"\(planPendingDeletion?.name ?? "")\"?",
                isPresented: deletionPresented,
                titleVisibility: .visible
            ) {
                Button("Delete plan", role: .destructive) {
                    if let plan = planPendingDeletion {
                        Task { await appState.delete(plan) }
                    }
                    planPendingDeletion = nil
                }
            } message: {
                Text("This removes the plan and its course. This can't be undone.")
            }
    }

    @ViewBuilder private var content: some View {
        if appState.plans.isEmpty {
            ContentUnavailableView {
                Label("No plans yet", systemImage: "figure.run")
            } description: {
                Text("Import a GPX course to set up your race.")
            } actions: {
                Button("Import course") { showingImport = true }
                    .buttonStyle(.borderedProminent)
            }
        } else {
            List {
                ForEach(appState.plans) { plan in
                    NavigationLink(value: plan.id) {
                        PlanRowView(plan: plan)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            planPendingDeletion = plan
                        }
                        Button("Duplicate", systemImage: "plus.square.on.square") {
                            Task { await appState.duplicate(plan) }
                        }
                    }
                }
            }
        }
    }

    private var deletionPresented: Binding<Bool> {
        Binding(
            get: { planPendingDeletion != nil },
            set: { presented in
                if !presented {
                    planPendingDeletion = nil
                }
            }
        )
    }
}

#Preview {
    NavigationStack {
        PlanListView()
    }
    .environment(AppState(dependencies: .preview()))
}
