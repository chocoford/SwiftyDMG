import SwiftUI

struct WorkspaceCommands: Commands {
    let delegate: AppDelegate
    @FocusedValue(PackagingModel.self) private var model

    var body: some Commands {
        #if SWIFTYDMG_WORKSPACE_SAVING
        // DocumentGroup supplies New, Open, Save, Save As, and Open Recent.
        CommandGroup(after: .newItem) {
            Button(.localizable(.menuNewWorkspaceFromApp), action: delegate.newWorkspaceFromApp)
                .keyboardShortcut("o", modifiers: [.command, .shift])
        }
        #else
        // Keep WindowGroup's native Close command; document saving is not part of this scene.
        CommandGroup(replacing: .newItem) {
            Button(.localizable(.menuNewWindow), action: delegate.newWorkspace)
                .keyboardShortcut("n")
            Button(.localizable(.menuOpenApp), action: delegate.openApp)
                .keyboardShortcut("o")
        }
        #endif
        #if SWIFTYDMG_WORKSPACE_SAVING
        CommandMenu(.localizable(.menuPresets)) {
            Button(.localizable(.menuImportPreset)) { model?.importPreset() }
                .disabled(model == nil || model?.isBuilding == true)
            Button(.localizable(.menuExportPreset)) { model?.exportPreset() }
                .disabled(model == nil)
            Divider()
            Button(.localizable(.menuResetDefaults)) { model?.options = .init() }
                .disabled(model == nil || model?.isBuilding == true)
        }
        #endif
    }
}
