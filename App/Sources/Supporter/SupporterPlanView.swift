import CheerPlanCore
import CheerPlanData
import CheerPlanUI
import MapKit
import SwiftUI

/// Wraps a leg index so sheets can present it.
struct LegSelection: Identifiable {
    let index: Int
    var id: Int { index }
}

/// The supporter's screen — the map is the app (spec §6.1). Tap the course to
/// add a viewing spot (choosing the pass on out-and-back or lapped courses);
/// tap away from the course to set where you start. The bottom panel is the
/// live-updating itinerary with feasibility traffic lights.
struct SupporterPlanView: View {
    @Environment(AppState.self) private var appState
    @State private var model: SupporterPlanModel
    @State private var pendingPasses: [CourseGeometry.SnapResult] = []
    @State private var showingAutoPropose = false
    @State private var fixLeg: LegSelection?
    @State private var raceModel: LiveRaceModel?

    init(model: SupporterPlanModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        MapReader { proxy in
            Map(initialPosition: .automatic) {
                CourseMapContent(course: model.runnerPlan.course)
                spotMarkers
                if let start = model.plan.spectatorStart {
                    Marker("You start here", systemImage: "figure.wave", coordinate: mapCoordinate(start))
                        .tint(.purple)
                }
            }
            .mapStyle(.standard(elevation: .flat))
            .onTapGesture { screenPoint in
                if let tapped = proxy.convert(screenPoint, from: .local) {
                    handleTap(Coordinate(latitude: tapped.latitude, longitude: tapped.longitude))
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            ItineraryPanelView(model: model, fixLeg: $fixLeg)
        }
        .navigationTitle("Cheer plan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                runnersMenu
                Button("Auto-propose", systemImage: "wand.and.stars") {
                    showingAutoPropose = true
                }
                Button("Race day", systemImage: "flag.checkered") {
                    Task { await startRaceDay() }
                }
                .disabled(model.itinerary.legs.isEmpty)
            }
        }
        .task { await model.load() }
        .sheet(isPresented: $showingAutoPropose) {
            AutoProposeView(model: model)
        }
        .fullScreenCover(item: $raceModel) { raceModel in
            RaceDayView(model: raceModel)
        }
        .sheet(item: $fixLeg) { selection in
            FixSuggestionsView(model: model, legIndex: selection.index)
        }
        .confirmationDialog(
            "The course passes here more than once",
            isPresented: passPickerPresented,
            titleVisibility: .visible
        ) {
            ForEach(pendingPasses, id: \.courseDistance) { pass in
                Button("Watch the pass at \(Formatters.distance(pass.courseDistance))") {
                    Task { await model.addSpot(atCourseDistance: pass.courseDistance) }
                    pendingPasses = []
                }
            }
        }
        .alert("Something went wrong", isPresented: errorPresented) {
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    /// Follow more runners in the same race (M6): the itinerary then requires
    /// arriving before the first of them and staying past the last.
    private var runnersMenu: some View {
        Menu("Runners", systemImage: "person.2") {
            let others = appState.plans.filter { $0.id != model.runnerPlan.id }
            if others.isEmpty {
                Text("Import another runner's plan to cheer for more people at once.")
            }
            ForEach(others) { other in
                Button {
                    Task { await model.toggleRunner(other) }
                } label: {
                    if model.isTracking(other) {
                        Label(other.name, systemImage: "checkmark")
                    } else {
                        Text(other.name)
                    }
                }
            }
        }
    }

    private func startRaceDay() async {
        do {
            let engine = try await LiveRaceEngine.startOrResume(
                supporterPlan: model.plan,
                runnerPlan: model.runnerPlan,
                itinerary: model.itinerary,
                store: appState.raceSessionStore
            )
            raceModel = LiveRaceModel(engine: engine, runnerPlan: model.runnerPlan, itinerary: model.itinerary)
        } catch {
            model.errorMessage = "Couldn't start race day: \(error.localizedDescription)"
        }
    }

    @MapContentBuilder private var spotMarkers: some MapContent {
        ForEach(model.itinerary.spots) { spot in
            Marker(
                markerTitle(for: spot),
                systemImage: "eyes",
                coordinate: mapCoordinate(spot.meetPoint.coordinate)
            )
            .tint(markerColor(for: spot))
        }
    }

    private func markerTitle(for spot: PlannedSpot) -> String {
        spot.meetPoint.name.isEmpty
            ? Formatters.distance(spot.meetPoint.courseDistance)
            : spot.meetPoint.name
    }

    private func markerColor(for spot: PlannedSpot) -> Color {
        guard let status = model.status(forSpot: spot.id) else { return CheerPlanColors.accent }
        return CheerPlanColors.color(for: status)
    }

    /// Near the course (≤ 250 m): add a spot, disambiguating multiple pass-bys.
    /// Away from it: set the spectator's start location.
    private func handleTap(_ location: Coordinate) {
        let passes = model.geometry.passBys(near: location, within: 250)
        if passes.isEmpty {
            Task { await model.setStart(location) }
        } else if passes.count == 1 {
            Task { await model.addSpot(atCourseDistance: passes[0].courseDistance) }
        } else {
            pendingPasses = passes
        }
    }

    private var passPickerPresented: Binding<Bool> {
        Binding(
            get: { !pendingPasses.isEmpty },
            set: { presented in
                if !presented {
                    pendingPasses = []
                }
            }
        )
    }

    private var errorPresented: Binding<Bool> {
        Binding(
            get: { model.errorMessage != nil },
            set: { presented in
                if !presented {
                    model.errorMessage = nil
                }
            }
        )
    }
}

#Preview {
    NavigationStack {
        SupporterPlanView(
            model: SupporterPlanModel(
                runnerPlan: PreviewData.plan,
                store: InMemorySupporterPlanStore(),
                planStore: InMemoryPlanStore(plans: [PreviewData.plan]),
                travelProvider: HeuristicTravelEstimator()
            )
        )
    }
    .environment(AppState(dependencies: .preview()))
}
