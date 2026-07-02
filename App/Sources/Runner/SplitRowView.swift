import CheerPlanCore
import SwiftUI

struct SplitRowView: View {
    let index: Int
    @Binding var split: PacingStrategy.Split

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Split \(index + 1)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Stepper(value: $split.distance, in: 1_000...50_000, step: 1_000) {
                LabeledContent("Length", value: Formatters.distance(split.distance))
            }
            Stepper(value: $split.secondsPerKilometer, in: 150...900, step: 5) {
                LabeledContent("Pace", value: Formatters.pace(secondsPerKilometer: split.secondsPerKilometer))
            }
        }
    }
}

#Preview {
    @Previewable @State var split = PacingStrategy.Split(distance: 5_000, secondsPerKilometer: 310)
    Form {
        SplitRowView(index: 0, split: $split)
    }
}
