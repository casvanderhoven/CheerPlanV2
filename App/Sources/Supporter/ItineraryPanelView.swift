import CheerPlanCore
import CheerPlanUI
import SwiftUI

/// The itinerary as a glanceable bottom panel: worst-status header, per-leg
/// rows, and the elevation profile annotated with the chosen spots.
struct ItineraryPanelView: View {
    let model: SupporterPlanModel
    @Binding var fixLeg: LegSelection?

    var body: some View {
        VStack(spacing: 10) {
            header
            if model.itinerary.spots.isEmpty {
                Text("Tap the course to add a viewing spot. Tap away from the course to set where you start.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                legRows
                if model.runnerPlan.course.hasElevation {
                    ElevationProfileView(
                        course: model.runnerPlan.course,
                        markedDistances: model.itinerary.spots.map(\.meetPoint.courseDistance)
                    )
                    .frame(height: 72)
                }
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private var header: some View {
        HStack {
            Text(model.itinerary.spots.isEmpty ? "No spots yet" : "\(model.itinerary.sightings) sightings")
                .font(.headline)
            if model.isEvaluating {
                ProgressView()
                    .controlSize(.small)
            }
            Spacer()
            if !model.itinerary.legs.isEmpty {
                StatusPill(status: model.itinerary.worstStatus)
            }
        }
    }

    private var legRows: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(Array(model.itinerary.legs.enumerated()), id: \.element.destination.id) { index, leg in
                    ItineraryLegRow(index: index, leg: leg, model: model) {
                        fixLeg = LegSelection(index: index)
                    }
                }
            }
        }
        .frame(maxHeight: 220)
    }
}
