import CheerPlanCore
import CheerPlanUI
import SwiftUI

/// Never dead-end the user (spec §6.3): every Not Feasible leg offers concrete,
/// tappable repairs straight from the engine's `FixSuggester`.
struct FixSuggestionsView: View {
    let model: SupporterPlanModel
    let legIndex: Int
    @Environment(\.dismiss) private var dismiss
    @State private var suggestions: [FixSuggestion] = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            List {
                if isLoading {
                    ProgressView("Looking for fixes…")
                } else if suggestions.isEmpty {
                    ContentUnavailableView(
                        "No automatic fix",
                        systemImage: "wrench.adjustable",
                        description: Text("Try removing the spot, or set an earlier departure.")
                    )
                } else {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button {
                            Task {
                                await model.apply(suggestion, toLegAt: legIndex)
                                dismiss()
                            }
                        } label: {
                            row(for: suggestion)
                        }
                    }
                }
            }
            .navigationTitle("Make it work")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                suggestions = await model.suggestions(forLegAt: legIndex)
                isLoading = false
            }
        }
        .presentationDetents([.medium])
    }

    @ViewBuilder private func row(for suggestion: FixSuggestion) -> some View {
        switch suggestion {
        case .changeTravelMode(let mode, let verdict):
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Go by \(mode.displayName.lowercased()) instead")
                    Text("Arrives with \(Formatters.duration(verdict.buffer)) to spare")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: ItineraryLegRow.icon(for: mode))
            }
        case .moveDestination(let meetPoint, let verdict):
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Move the spot to \(Formatters.distance(meetPoint.courseDistance))")
                    Text("Nearest reachable point · \(Formatters.duration(verdict.buffer)) to spare")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "arrow.right.to.line")
            }
        case .removeDestinationSpot:
            Label("Skip this spot", systemImage: "xmark.circle")
        case .removeSourceSpot:
            Label("Skip the previous spot instead", systemImage: "xmark.circle.fill")
        }
    }
}
