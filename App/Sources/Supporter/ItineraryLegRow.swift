import CheerPlanCore
import CheerPlanUI
import SwiftUI

/// One hop of the supporter's day: where, when to leave, how to travel, and the
/// traffic light. Tapping a red pill opens the fix suggestions.
struct ItineraryLegRow: View {
    let index: Int
    let leg: TravelLeg
    let model: SupporterPlanModel
    var onFix: () -> Void

    @State private var showingAssign = false
    @State private var assigneeDraft = ""

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(timing)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let assignee = model.assignee(forSpot: leg.destination.id) {
                    Label(assignee, systemImage: "person.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            assignButton
            modeMenu
            statusButton
            Button("Remove spot", systemImage: "xmark.circle", role: .destructive) {
                Task { await model.removeSpot(id: leg.destination.id) }
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .alert("Who covers this spot?", isPresented: $showingAssign) {
            TextField("Name", text: $assigneeDraft)
            Button("Assign") {
                let trimmed = assigneeDraft.trimmingCharacters(in: .whitespaces)
                Task { await model.setAssignee(trimmed.isEmpty ? nil : trimmed, forSpot: leg.destination.id) }
            }
            Button("Clear", role: .destructive) {
                Task { await model.setAssignee(nil, forSpot: leg.destination.id) }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var title: String {
        let name = leg.destination.name.isEmpty ? "Spot \(index + 1)" : leg.destination.name
        return "\(name) · \(Formatters.distance(leg.destination.courseDistance))"
    }

    private var timing: String {
        let leave = LocalizedFormatters.time(leg.latestDeparture)
        let suffix = leg.estimate.isEstimate ? " · est." : ""
        if let window = model.passWindow(atDistance: leg.destination.courseDistance) {
            let first = LocalizedFormatters.time(window.first)
            let last = LocalizedFormatters.time(window.last)
            return "Leave by \(leave) · runners ~\(first)–\(last)\(suffix)"
        }
        let arrives = LocalizedFormatters.time(leg.runnerArrival)
        return "Leave by \(leave) · runner ~\(arrives)\(suffix)"
    }

    private var assignButton: some View {
        Button("Assign", systemImage: "person.crop.circle.badge.plus") {
            assigneeDraft = model.assignee(forSpot: leg.destination.id) ?? ""
            showingAssign = true
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
    }

    private var modeMenu: some View {
        Menu {
            ForEach(TravelMode.allCases, id: \.self) { mode in
                Button(mode.displayName, systemImage: Self.icon(for: mode)) {
                    Task { await model.setMode(mode, forSpot: leg.destination.id) }
                }
            }
        } label: {
            Image(systemName: Self.icon(for: leg.estimate.mode))
        }
    }

    private var statusButton: some View {
        Button {
            if leg.verdict.status == .notFeasible {
                onFix()
            }
        } label: {
            StatusPill(status: leg.verdict.status)
        }
        .buttonStyle(.plain)
    }

    static func icon(for mode: TravelMode) -> String {
        switch mode {
        case .walk: "figure.walk"
        case .cycle: "bicycle"
        case .drive: "car"
        case .transit: "tram"
        }
    }
}
