import AppKit
import SwiftUI

#if !SWIFTYDMG_WORKSPACE_SAVING
/// A unique launch value allows independent windows for the same input app.
struct WorkspaceWindowRequest: Codable, Hashable {
    let id: UUID
    let workspace: WorkspaceState

    init(workspace: WorkspaceState) {
        id = UUID()
        self.workspace = workspace
    }

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct SessionWorkspaceView: View {
    @Environment(\.openWindow) private var openWindow
    @State private var model: PackagingModel
    let delegate: AppDelegate

    init(workspace: WorkspaceState, delegate: AppDelegate) {
        _model = State(initialValue: PackagingModel(workspace: workspace))
        self.delegate = delegate
    }

    var body: some View {
        ContentView(model: model, delegate: delegate)
            .focusedSceneValue(model)
            .onAppear {
                let action = openWindow
                delegate.connectWorkspaceCreation { workspace in
                    action(id: "workspace", value: WorkspaceWindowRequest(workspace: workspace))
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                model.refreshAutomaticOutputName()
            }
    }
}
#endif
