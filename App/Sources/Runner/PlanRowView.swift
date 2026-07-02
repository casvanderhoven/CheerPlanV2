import CheerPlanCore
import CheerPlanUI
import SwiftUI

struct PlanRowView: View {
    let plan: RunnerPlan

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(plan.name)
                .font(.headline)
            Text(summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private var summary: String {
        let distance = Formatters.distance(plan.course.totalDistance)
        return "\(distance) · starts \(LocalizedFormatters.dayAndTime(plan.startTime))"
    }
}

#Preview {
    List {
        PlanRowView(plan: PreviewData.plan)
    }
}
