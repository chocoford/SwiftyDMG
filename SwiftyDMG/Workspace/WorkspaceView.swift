import SwiftUI

struct WorkspaceView: View {
    @Bindable var model: PackagingModel
    @Binding var inspectorTab: InspectorTab
    @Binding var inspectorPresented: Bool
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var selection: WorkspaceItem? = .app

    var body: some View {
        workspaceContent
        .inspector(isPresented: $inspectorPresented) {
            VStack(spacing: 0) {
                InspectorTabPicker(selection: $inspectorTab)
                    .padding(12)
                Divider()
                if inspectorTab == .settings {
                    PackagingSettingsView(model: model, selection: selection)
                } else {
                    BuildInspector(model: model)
                }
            }
            .inspectorColumnWidth(min: 300, ideal: 320, max: 380)
        }
        .onChange(of: selection) { _, selected in
            if selected != nil {
                inspectorTab = .settings
                inspectorPresented = true
            }
        }
    }

    @ViewBuilder
    private var workspaceContent: some View {
        #if SWIFTYDMG_SIDEBAR
        NavigationSplitView(columnVisibility: $columnVisibility) {
            WorkspaceSidebar(model: model, selection: $selection)
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 300)
        } detail: {
            PreviewCanvas(options: $model.options, sourceURL: model.sourceURL, isBuilding: model.isBuilding)
        }
        #else
        PreviewCanvas(options: $model.options, sourceURL: model.sourceURL, isBuilding: model.isBuilding)
        #endif
    }
}
