import AppKit
import SwiftUI

enum WorkspaceItem: Hashable {
    case app, applications
    case extra(UUID)
}

struct WorkspaceSidebar: View {
    @Bindable var model: PackagingModel
    @Binding var selection: WorkspaceItem?

    var body: some View {
        List(selection: $selection) {
            Section(.localizable(.sidebarContentsSection)) {
                if let source = model.sourceURL {
                    SidebarFileRow(name: source.lastPathComponent, url: source)
                        .tag(WorkspaceItem.app)
                        .contextMenu {
                            Button(.localizable(.sidebarChangeApp), action: model.chooseApp).disabled(model.isBuilding)
                            Button(.localizable(.generalShowInFinder)) { NSWorkspace.shared.activateFileViewerSelecting([source]) }
                        }
                }
                if model.options.includeApplications {
                    Label(.localizable(.sidebarApplications), systemImage: "folder.badge.gearshape")
                        .tag(WorkspaceItem.applications)
                        .contextMenu { Button(.localizable(.sidebarRemoveLink), action: removeApplications).disabled(model.isBuilding) }
                }
                ForEach(model.options.extraItems) { item in
                    SidebarFileRow(name: item.name, url: item.url)
                        .tag(WorkspaceItem.extra(item.id))
                        .contextMenu {
                            Button(.localizable(.sidebarRenameFile)) { model.renameFile(item.id) }.disabled(model.isBuilding)
                            Button(.localizable(.sidebarReplaceFile)) { model.replaceFile(item.id) }.disabled(model.isBuilding)
                            Button(.localizable(.generalButtonRemove)) { removeExtra(item.id) }.disabled(model.isBuilding)
                            Button(.localizable(.generalShowInFinder)) { NSWorkspace.shared.activateFileViewerSelecting([item.url]) }
                        }
                }
            }
        }
        .listStyle(.sidebar)
        .onDeleteCommand(perform: removeSelection)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                Divider()
                HStack {
                    Menu {
                        Button(.localizable(.inspectorAddFiles), action: model.addFiles)
                        if !model.options.includeApplications {
                            Button(.localizable(.sidebarAddApplicationsLink)) { model.options.includeApplications = true }
                        }
                    } label: { Image(systemName: "plus") }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .help(String(localizable: .sidebarAddContentHelp))
                    .disabled(model.isBuilding)
                    Spacer()
                    Button(action: removeSelection) { Image(systemName: "minus") }
                        .buttonStyle(.borderless)
                        .help(String(localizable: .sidebarRemoveItemHelp))
                        .disabled(model.isBuilding || !canRemoveSelection)
                }.padding(.horizontal, 14).padding(.vertical, 10)
            }
        }
        .accessibilityIdentifier("workspaceSidebar")
    }

    private var canRemoveSelection: Bool {
        guard let selection else { return false }
        switch selection {
        case .applications, .extra: return true
        case .app: return false
        }
    }

    private func removeSelection() {
        guard !model.isBuilding, let selection else { return }
        switch selection {
        case .applications: removeApplications()
        case .extra(let id): removeExtra(id)
        case .app: break
        }
    }

    private func removeApplications() {
        model.options.includeApplications = false
        selection = .app
    }

    private func removeExtra(_ id: UUID) {
        model.options.extraItems.removeAll { $0.id == id }
        selection = .app
    }
}

private struct SidebarFileRow: View {
    let name: String
    let url: URL

    var body: some View {
        HStack(spacing: 8) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().frame(width: 20, height: 20)
            Text(verbatim: name).lineLimit(1).truncationMode(.middle)
            Spacer(minLength: 0)
            if !FileManager.default.fileExists(atPath: url.path) {
                Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange).help(String(localizable: .sidebarMissingFileHelp))
            }
        }.help(url.path)
    }
}
