import CheerPlanCore
import CheerPlanData
import CheerPlanUI
import SwiftUI
import UniformTypeIdentifiers

/// Two ways in: pick a .gpx file, or paste a URL. Every failure states what
/// happened and what to do next (spec §6.3 — never dead-end the user).
struct CourseImportView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var showingFilePicker = false
    @State private var urlText = ""
    @State private var isDownloading = false
    @State private var importError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("From a file") {
                    Button("Choose a GPX file", systemImage: "doc") {
                        showingFilePicker = true
                    }
                }
                Section("From the web") {
                    TextField("https://example.com/course.gpx", text: $urlText)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("Download course", systemImage: "arrow.down.circle") {
                        Task { await importFromURL() }
                    }
                    .disabled(urlText.isEmpty || isDownloading)
                    if isDownloading {
                        ProgressView()
                    }
                }
                if let importError {
                    Section {
                        Label(importError, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(CheerPlanColors.notFeasible)
                    }
                }
            }
            .navigationTitle("Import course")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .fileImporter(isPresented: $showingFilePicker, allowedContentTypes: gpxTypes) { result in
                Task { await importFromFile(result) }
            }
        }
    }

    private var gpxTypes: [UTType] {
        var types: [UTType] = [.cheerplan, .xml, .data]
        if let gpx = UTType(filenameExtension: "gpx") {
            types.insert(gpx, at: 0)
        }
        return types
    }

    private func importFromFile(_ result: Result<URL, Error>) async {
        switch result {
        case .failure(let error):
            importError = "Couldn't open the file: \(error.localizedDescription). Try picking it again."
        case .success(let url):
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            do {
                let data = try Data(contentsOf: url)
                // A shared .cheerplan file carries a full plan; anything else is GPX.
                if let shared = try? PlanShareCodec.decodePlan(fromFileData: data) {
                    await appState.save(shared)
                    dismiss()
                    return
                }
                try await makePlan(from: data, suggestedName: url.deletingPathExtension().lastPathComponent)
            } catch {
                importError = message(for: error)
            }
        }
    }

    private func importFromURL() async {
        let trimmed = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), url.scheme == "https" || url.scheme == "http" else {
            importError = "That doesn't look like a valid link. Paste a full URL to a .gpx file."
            return
        }
        isDownloading = true
        defer { isDownloading = false }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            try await makePlan(from: data, suggestedName: url.deletingPathExtension().lastPathComponent)
        } catch {
            importError = message(for: error)
        }
    }

    private func makePlan(from data: Data, suggestedName: String) async throws {
        let course = try GPXParser.parseCourse(from: data)
        let plan = RunnerPlan(
            name: course.name.isEmpty ? suggestedName : course.name,
            course: course,
            startTime: defaultStartTime(),
            pacing: .steady(secondsPerKilometer: 360)
        )
        await appState.save(plan)
        dismiss()
    }

    /// The next 9:00 — a plausible race start the user will adjust anyway.
    private func defaultStartTime() -> Date {
        let nine = DateComponents(hour: 9, minute: 0)
        return Calendar.current.nextDate(after: .now, matching: nine, matchingPolicy: .nextTime) ?? .now
    }

    private func message(for error: Error) -> String {
        switch error {
        case GPXError.invalidXML:
            "That file isn't valid GPX. Export the course again from your race site or route planner."
        case GPXError.noTrack, GPXError.insufficientPoints:
            "The file parsed, but there's no usable track in it. "
                + "Check that it contains the course itself, not just waypoints."
        case is URLError:
            "The download failed. Check the link and your connection, then try again."
        default:
            "Import failed: \(error.localizedDescription)"
        }
    }
}

#Preview {
    CourseImportView()
        .environment(AppState(dependencies: .preview()))
}
