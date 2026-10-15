import SwiftUI

struct WorkspaceCommands: Commands {
    let delegate: ApplicationDelegate
    @FocusedValue(PackagingModel.self) private var model

    var body: some Commands {
        // DocumentGroup supplies New, Open, Save, Save As, and Open Recent.
        CommandGroup(after: .newItem) {
            Button("New Workspace from App…", action: delegate.newWorkspaceFromApp)
                .keyboardShortcut("o", modifiers: [.command, .shift])
        }
        CommandMenu("Presets") {
            Button("Import Preset…") { model?.importPreset() }
                .disabled(model == nil || model?.isBuilding == true)
            Button("Export Preset…") { model?.exportPreset() }
                .disabled(model == nil)
            Divider()
            Button("Reset to Defaults") { model?.options = .init() }
                .disabled(model == nil || model?.isBuilding == true)
        }
    }
}
