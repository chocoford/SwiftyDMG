import AppKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let swiftyDMGWorkspace = UTType(exportedAs: "com.chocoford.swiftydmg.workspace", conformingTo: .json)
}

/// Durable settings only. Build progress and logs belong to the open window.
struct WorkspaceState: Codable, Equatable, Sendable {
    var sourceURL: URL?
    var outputURL: URL?
    var usesAutomaticOutputName = true
    var options = PackagingOptions()
}

struct WorkspaceDocument: FileDocument, Sendable {
    static var readableContentTypes: [UTType] { [.swiftyDMGWorkspace] }
    var workspace: WorkspaceState

    init(workspace: WorkspaceState = .init()) {
        self.workspace = workspace
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let archive = try JSONDecoder().decode(WorkspaceArchive.self, from: data)
        guard archive.formatVersion == 1 else {
            throw PackagingError.invalid(String(localized: "This workspace file version is not supported."))
        }
        workspace = archive.restoredWorkspace()
        let references = [workspace.sourceURL, workspace.outputURL, workspace.options.backgroundURL, workspace.options.diskIconURL]
            .compactMap { $0 } + workspace.options.extraItems.map(\.url)
        guard references.allSatisfy(\.isFileURL) else {
            throw PackagingError.invalid(String(localized: "The app and assets in a workspace must refer to local files."))
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return FileWrapper(regularFileWithContents: try encoder.encode(WorkspaceArchive(workspace: workspace)))
    }
}

/// Keep ordinary URLs as a fallback, with bookmarks to recover moved local files.
/// Referenced Apps and assets are not copied into the workspace document.
private struct WorkspaceArchive: Codable {
    let formatVersion: Int
    var workspace: WorkspaceState
    var bookmarks: [String: Data]

    init(workspace: WorkspaceState) {
        formatVersion = 1
        self.workspace = workspace
        var references: [String: URL] = [:]
        references["source"] = workspace.sourceURL
        references["outputDirectory"] = workspace.outputURL?.deletingLastPathComponent()
        references["background"] = workspace.options.backgroundURL
        references["diskIcon"] = workspace.options.diskIconURL
        for item in workspace.options.extraItems { references[item.id.uuidString] = item.url }
        bookmarks = references.compactMapValues {
            try? $0.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
        }
    }

    func restoredWorkspace() -> WorkspaceState {
        var restored = workspace
        restored.sourceURL = resolve("source", fallback: restored.sourceURL)
        restored.options.backgroundURL = resolve("background", fallback: restored.options.backgroundURL)
        restored.options.diskIconURL = resolve("diskIcon", fallback: restored.options.diskIconURL)
        if let output = restored.outputURL,
           let directory = resolve("outputDirectory", fallback: output.deletingLastPathComponent()) {
            restored.outputURL = directory.appendingPathComponent(output.lastPathComponent)
        }
        for index in restored.options.extraItems.indices {
            let item = restored.options.extraItems[index]
            restored.options.extraItems[index].url = resolve(item.id.uuidString, fallback: item.url) ?? item.url
        }
        return restored
    }

    private func resolve(_ key: String, fallback: URL?) -> URL? {
        guard let data = bookmarks[key] else { return fallback }
        var stale = false
        return (try? URL(resolvingBookmarkData: data, options: [.withoutUI, .withoutMounting], relativeTo: nil, bookmarkDataIsStale: &stale)) ?? fallback
    }
}

/// Each document owns its model; changes flow through the native document binding.
struct WorkspaceDocumentView: View {
    @Environment(\.newDocument) private var newDocument
    @Binding var document: WorkspaceDocument
    let fileURL: URL?
    let delegate: ApplicationDelegate
    @State private var model: PackagingModel

    init(document: Binding<WorkspaceDocument>, fileURL: URL?, delegate: ApplicationDelegate) {
        _document = document
        self.fileURL = fileURL
        self.delegate = delegate
        _model = State(initialValue: PackagingModel(workspace: document.wrappedValue.workspace))
    }

    var body: some View {
        ContentView(model: model, delegate: delegate, documentTitle: fileURL?.deletingPathExtension().lastPathComponent)
            .focusedSceneValue(model)
            .onAppear(perform: connectDocument)
            .onDisappear { model.onWorkspaceChange = nil }
            .onChange(of: document.workspace) { _, workspace in
                if model.workspace != workspace { model.restoreWorkspace(workspace) }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                model.refreshAutomaticOutputName()
            }
    }

    private func connectDocument() {
        let binding = $document
        model.onWorkspaceChange = { workspace in
            if binding.wrappedValue.workspace != workspace {
                binding.wrappedValue.workspace = workspace
            }
        }
        if document.workspace != model.workspace { document.workspace = model.workspace }
        let newDocumentAction = newDocument
        delegate.connectWorkspaceCreation { workspace in
            newDocumentAction(WorkspaceDocument(workspace: workspace))
        }
    }
}
