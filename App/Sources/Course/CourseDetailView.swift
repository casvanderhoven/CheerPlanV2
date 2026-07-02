import CheerPlanCore
import CheerPlanUI
import SwiftUI

/// The map is the app (spec §6.1): the course full-bleed, key facts and the
/// elevation profile layered on top, the editor as a sheet.
struct CourseDetailView: View {
    @Environment(AppState.self) private var appState
    let plan: RunnerPlan
    @State private var showingEditor = false

    /// Always render the freshest copy; `plan` is just the navigation payload.
    private var currentPlan: RunnerPlan {
        appState.plan(id: plan.id) ?? plan
    }

    var body: some View {
        CourseMapView(course: currentPlan.course)
            .safeAreaInset(edge: .bottom) {
                summaryPanel
            }
            .navigationTitle(currentPlan.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit plan", systemImage: "slider.horizontal.3") {
                        showingEditor = true
                    }
                }
            }
            .sheet(isPresented: $showingEditor) {
                PlanEditorView(plan: currentPlan)
            }
    }

    private var summaryPanel: some View {
        VStack(spacing: 12) {
            HStack {
                stat("Distance", Formatters.distance(currentPlan.course.totalDistance))
                stat("Climb", climbText)
                stat("Start", LocalizedFormatters.time(currentPlan.startTime))
                stat("Finish", "~" + LocalizedFormatters.time(currentPlan.plannedFinish))
            }
            if currentPlan.course.hasElevation {
                ElevationProfileView(course: currentPlan.course)
                    .frame(height: 96)
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(CheerPlanTypography.statValue)
            Text(label)
                .font(CheerPlanTypography.statLabel)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var climbText: String {
        guard currentPlan.course.hasElevation else { return "–" }
        return "\(Int(currentPlan.course.elevationGain.rounded())) m"
    }
}

#Preview {
    NavigationStack {
        CourseDetailView(plan: PreviewData.plan)
    }
    .environment(AppState(dependencies: .preview()))
}
