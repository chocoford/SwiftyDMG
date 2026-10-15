import SwiftUI

struct WorkspaceCommands: Commands {
    let delegate: ApplicationDelegate
    @FocusedValue(PackagingModel.self) private var model

    var body: some Commands {
        #if SWIFTYDMG_WORKSPACE_SAVING
        // DocumentGroup supplies New, Open, Save, Save As, and Open Recent.
        CommandGroup(after: .newItem) {
            Button("New Workspace from App…", action: delegate.newWorkspaceFromApp)
                .keyboardShortcut("o", modifiers: [.command, .shift])
        }
        #else
        CommandGroup(replacing: .newItem) {
            Button("New Window", action: delegate.newWorkspace)
                .keyboardShortcut("n")
            Button("Open App…", action: delegate.openApp)
                .keyboardShortcut("o")
        }
        CommandGroup(replacing: .saveItem) {}
        #endif
        #if SWIFTYDMG_WORKSPACE_SAVING
        CommandMenu("Presets") {
            Button("Import Preset…") { model?.importPreset() }
                .disabled(model == nil || model?.isBuilding == true)
            Button("Export Preset…") { model?.exportPreset() }
                .disabled(model == nil)
            Divider()
            Button("Reset to Defaults") { model?.options = .init() }
                .disabled(model == nil || model?.isBuilding == true)
        }
        #endif
    }
}
