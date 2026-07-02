import CheerPlanCore
import CheerPlanUI
import SwiftUI

/// The race-day takeover, designed for a stressed person walking fast in a
/// crowd (spec §6.2): one primary number, one primary instruction, thumb-reach
/// actions, huge type.
struct RaceDayView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: LiveRaceModel
    @State private var showingRecalibrate = false
    @State private var confirmingEnd = false

    init(model: LiveRaceModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Race day")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("End", role: .destructive) { confirmingEnd = true }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button("Recalibrate", systemImage: "scope") { showingRecalibrate = true }
                    }
                }
                .sheet(isPresented: $showingRecalibrate) {
                    RecalibrateView(model: model)
                }
                .confirmationDialog("End race day?", isPresented: $confirmingEnd, titleVisibility: .visible) {
                    Button("End race day", role: .destructive) {
                        Task { await model.endRace() }
                    }
                } message: {
                    Text("Stops tracking and clears the Live Activity.")
                }
                .alert("Something went wrong", isPresented: errorPresented) {
                    Button("OK", role: .cancel) { model.errorMessage = nil }
                } message: {
                    Text(model.errorMessage ?? "")
                }
                .task {
                    await model.start()
                    while !Task.isCancelled {
                        try? await Task.sleep(for: .seconds(1))
                        await model.tick()
                    }
                }
                .onChange(of: model.isEnded) {
                    if model.isEnded {
                        dismiss()
                    }
                }
        }
        .interactiveDismissDisabled()
    }

    @ViewBuilder private var content: some View {
        if let snapshot = model.snapshot {
            ScrollView {
                VStack(spacing: 24) {
                    phaseHeader(snapshot)
                    heroSection(snapshot)
                    runnerStatus(snapshot)
                    if snapshot.nextLegIndex != nil {
                        passedButton
                    }
                    legList(snapshot)
                }
                .padding()
            }
        } else {
            ProgressView("Starting race day…")
        }
    }

    private func phaseHeader(_ snapshot: RaceSnapshot) -> some View {
        Text(phaseTitle(snapshot.phase))
            .font(CheerPlanTypography.instruction)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func phaseTitle(_ phase: RaceSnapshot.Phase) -> String {
        switch phase {
        case .beforeStart: "Before the gun"
        case .stay: "You're fine — enjoy it"
        case .go: "GO"
        case .finished: "That's a wrap 🎉"
        }
    }

    @ViewBuilder private func heroSection(_ snapshot: RaceSnapshot) -> some View {
        if let index = snapshot.nextLegIndex, let leaveBy = snapshot.leaveBy {
            VStack(spacing: 8) {
                if case .go = snapshot.phase {
                    Text("Leave now")
                        .font(CheerPlanTypography.heroNumber)
                        .foregroundStyle(CheerPlanColors.notFeasible)
                } else {
                    Text(Formatters.countdown(leaveBy.timeIntervalSince(snapshot.now)))
                        .font(CheerPlanTypography.heroNumber)
                    Text("until you leave for \(model.spotLabel(forLegAt: index))")
                        .font(CheerPlanTypography.statLabel)
                        .foregroundStyle(.secondary)
                }
                Text(model.instruction(forLegAt: index, leaveNow: false))
                    .font(CheerPlanTypography.instruction)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        } else if case .finished = snapshot.phase {
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(CheerPlanColors.ok)
                Text("Head to the finish celebrations!")
                    .font(CheerPlanTypography.instruction)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func runnerStatus(_ snapshot: RaceSnapshot) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Runner around \(Formatters.distance(snapshot.runnerCourseDistance))")
                    .font(CheerPlanTypography.statValue)
                Text(deltaText(snapshot.scheduleDelta))
                    .font(CheerPlanTypography.statLabel)
                    .foregroundStyle(deltaColor(snapshot.scheduleDelta))
            }
            Spacer()
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func deltaText(_ delta: TimeInterval) -> String {
        if abs(delta) < 30 {
            return "on plan"
        }
        let amount = Formatters.duration(abs(delta))
        return delta > 0 ? "\(amount) behind plan" : "\(amount) ahead of plan"
    }

    private func deltaColor(_ delta: TimeInterval) -> Color {
        abs(delta) < 30 ? CheerPlanColors.ok : CheerPlanColors.tight
    }

    private var passedButton: some View {
        Button {
            Task { await model.runnerPassedNextSpot() }
        } label: {
            Label("Runner passed me", systemImage: "hand.wave.fill")
                .font(CheerPlanTypography.instruction)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .buttonStyle(.borderedProminent)
    }

    private func legList(_ snapshot: RaceSnapshot) -> some View {
        VStack(spacing: 6) {
            ForEach(Array(model.itinerary.legs.enumerated()), id: \.element.destination.id) { index, _ in
                HStack {
                    Image(systemName: snapshot.passedLegIndexes.contains(index)
                        ? "checkmark.circle.fill"
                        : "circle")
                        .foregroundStyle(snapshot.passedLegIndexes.contains(index)
                            ? CheerPlanColors.ok
                            : Color.secondary)
                    Text(model.spotLabel(forLegAt: index))
                    Spacer()
                    if snapshot.projectedArrivals.indices.contains(index) {
                        Text("runner ~" + LocalizedFormatters.time(snapshot.projectedArrivals[index]))
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.subheadline)
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
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
