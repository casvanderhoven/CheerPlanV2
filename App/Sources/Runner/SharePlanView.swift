import CheerPlanCore
import CheerPlanData
import CheerPlanUI
import SwiftUI
import UniformTypeIdentifiers

/// Sharing is a link — v1's biggest lesson. One tap to send; opens straight in
/// CheerPlan. The `.cheerplan` file is the full-fidelity offline escape hatch.
struct SharePlanView: View {
    let plan: RunnerPlan
    @Environment(\.dismiss) private var dismiss
    @State private var shareURL: URL?
    @State private var exporting = false
    @State private var shareError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Send a link") {
                    if let shareURL {
                        ShareLink(item: shareURL, subject: Text(plan.name)) {
                            Label("Share plan link", systemImage: "link")
                        }
                        Text("Opens directly in CheerPlan. The course is lightly simplified to fit in a link.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                Section("Send a file") {
                    Button("Export .cheerplan file", systemImage: "doc.badge.arrow.up") {
                        exporting = true
                    }
                    Text("Full-fidelity backup — works over AirDrop, no internet needed.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if let shareError {
                    Section {
                        Label(shareError, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(CheerPlanColors.notFeasible)
                    }
                }
            }
            .navigationTitle("Share \"\(plan.name)\"")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                do {
                    shareURL = try PlanShareCodec.shareURL(for: plan)
                } catch {
                    shareError = "Couldn't build a share link: \(error.localizedDescription). "
                        + "The file export below still works."
                }
            }
            .fileExporter(
                isPresented: $exporting,
                document: CheerPlanDocument(plan: plan),
                contentType: .cheerplan,
                defaultFilename: plan.name
            ) { result in
                if case .failure(let error) = result {
                    shareError = "Export failed: \(error.localizedDescription)"
                }
            }
        }
    }
}

#Preview {
    SharePlanView(plan: PreviewData.plan)
}
