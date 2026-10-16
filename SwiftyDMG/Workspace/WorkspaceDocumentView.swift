import AppKit
import SwiftUI

/// Each document owns its model; changes flow through the native document binding.
struct WorkspaceDocumentView: View {
    @Environment(\.newDocument) private var newDocument
    @Binding var document: WorkspaceDocument
    let fileURL: URL?
    let delegate: AppDelegate
    @State private var model: PackagingModel

    init(document: Binding<WorkspaceDocument>, fileURL: URL?, delegate: AppDelegate) {
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
