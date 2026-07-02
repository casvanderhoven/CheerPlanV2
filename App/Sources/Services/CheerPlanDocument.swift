import CheerPlanCore
import CheerPlanData
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    /// The `.cheerplan` file — declared in the app's Info.plist (project.yml).
    static let cheerplan = UTType(exportedAs: "com.cheerplan.plan", conformingTo: .json)
}

/// FileDocument wrapper so `fileExporter` can write `.cheerplan` files.
struct CheerPlanDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.cheerplan, .json]

    var plan: RunnerPlan

    init(plan: RunnerPlan) {
        self.plan = plan
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        plan = try PlanShareCodec.decodePlan(fromFileData: data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: try PlanShareCodec.fileData(for: plan))
    }
}
