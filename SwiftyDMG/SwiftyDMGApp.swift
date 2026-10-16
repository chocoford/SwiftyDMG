import AppKit
import SwiftUI

@main
struct SwiftyDMGApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        workspaceScene
        .defaultSize(width: 400, height: 300)
        .commands {
            WorkspaceCommands(delegate: delegate)
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updates: delegate.updates)
            }
            #if SWIFTYDMG_SIDEBAR
            SidebarCommands()
            #endif
        }
        Settings {
            UpdateSettingsView(updates: delegate.updates)
        }
    }

    @SceneBuilder
    private var workspaceScene: some Scene {
        #if SWIFTYDMG_WORKSPACE_SAVING
        DocumentGroup(newDocument: WorkspaceDocument()) { configuration in
            WorkspaceDocumentView(document: configuration.$document, fileURL: configuration.fileURL, delegate: delegate)
        }
        #else
        WindowGroup("SwiftyDMG", id: "workspace", for: WorkspaceWindowRequest.self) { $request in
            SessionWorkspaceView(workspace: request?.workspace ?? .init(), delegate: delegate)
        }
        #endif
    }
}
