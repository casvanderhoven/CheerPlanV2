import CheerPlanCore
import SwiftUI

/// Steady pace, target finish time, or per-split paces — three ways to edit
/// the same `PacingStrategy` binding.
struct PacingEditorView: View {
    @Binding var pacing: PacingStrategy
    let courseDistance: Double

    private enum Mode: String, CaseIterable, Identifiable {
        case steady = "Steady"
        case finishTime = "Finish time"
        case splits = "Splits"
        var id: String { rawValue }
    }

    @State private var mode: Mode
    @State private var paceSeconds: Double
    @State private var finishSeconds: Double
    @State private var splits: [PacingStrategy.Split]

    init(pacing: Binding<PacingStrategy>, courseDistance: Double) {
        _pacing = pacing
        self.courseDistance = courseDistance
        let model = PaceModel(pacing: pacing.wrappedValue, courseDistance: courseDistance)
        let averagePace = courseDistance > 0 ? model.totalDuration / courseDistance * 1000 : 360

        switch pacing.wrappedValue {
        case .steady(let pace):
            _mode = State(initialValue: .steady)
            _paceSeconds = State(initialValue: pace)
            _splits = State(initialValue: Self.defaultSplits(pace: pace, courseDistance: courseDistance))
        case .splits(let existing):
            _mode = State(initialValue: .splits)
            _paceSeconds = State(initialValue: averagePace)
            _splits = State(initialValue: existing)
        }
        _finishSeconds = State(initialValue: model.totalDuration)
    }

    var body: some View {
        Picker("Pacing", selection: $mode) {
            ForEach(Mode.allCases) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)

        modeContent
            .onChange(of: mode) { commit() }
            .onChange(of: paceSeconds) { commit() }
            .onChange(of: finishSeconds) { commit() }
            .onChange(of: splits) { commit() }
    }

    @ViewBuilder private var modeContent: some View {
        switch mode {
        case .steady:
            Stepper(value: $paceSeconds, in: 150...900, step: 5) {
                LabeledContent("Pace", value: Formatters.pace(secondsPerKilometer: paceSeconds))
            }
        case .finishTime:
            Stepper(value: $finishSeconds, in: 600...43_200, step: 300) {
                LabeledContent("Finish in", value: Formatters.duration(finishSeconds))
            }
            LabeledContent("Implied pace", value: impliedPace)
        case .splits:
            ForEach(splits.indices, id: \.self) { index in
                SplitRowView(index: index, split: $splits[index])
            }
            .onDelete { offsets in
                splits.remove(atOffsets: offsets)
            }
            Button("Add split", systemImage: "plus") {
                splits.append(.init(distance: 5_000, secondsPerKilometer: paceSeconds))
            }
        }
    }

    private var impliedPace: String {
        guard courseDistance > 0 else { return "–" }
        return Formatters.pace(secondsPerKilometer: finishSeconds / courseDistance * 1000)
    }

    private func commit() {
        switch mode {
        case .steady:
            pacing = .steady(secondsPerKilometer: paceSeconds)
        case .finishTime:
            pacing = .targetFinish(courseDistance: courseDistance, duration: finishSeconds)
        case .splits:
            pacing = .splits(splits)
        }
    }

    /// A gentle negative split as the starting point when switching to splits.
    private static func defaultSplits(pace: Double, courseDistance: Double) -> [PacingStrategy.Split] {
        let half = max(courseDistance / 2, 1_000)
        return [
            .init(distance: half, secondsPerKilometer: pace + 5),
            .init(distance: half, secondsPerKilometer: max(150, pace - 5))
        ]
    }
}

#Preview {
    @Previewable @State var pacing = PacingStrategy.steady(secondsPerKilometer: 330)
    Form {
        PacingEditorView(pacing: $pacing, courseDistance: 42_195)
    }
}
