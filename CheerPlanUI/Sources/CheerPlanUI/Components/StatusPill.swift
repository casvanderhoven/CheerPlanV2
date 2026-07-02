import CheerPlanCore
import SwiftUI

/// The feasibility traffic light as a compact pill.
public struct StatusPill: View {
    public let status: FeasibilityStatus

    public init(status: FeasibilityStatus) {
        self.status = status
    }

    public var body: some View {
        Text(label)
            .font(CheerPlanTypography.statLabel)
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(CheerPlanColors.color(for: status), in: Capsule())
            .accessibilityLabel(label)
    }

    private var label: String {
        switch status {
        case .ok: "OK"
        case .tight: "Tight"
        case .notFeasible: "Not feasible"
        }
    }
}

#Preview {
    VStack(spacing: 8) {
        StatusPill(status: .ok)
        StatusPill(status: .tight)
        StatusPill(status: .notFeasible)
    }
    .padding()
}
