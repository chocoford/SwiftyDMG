import AppKit
import SwiftUI

enum WorkspaceItem: Hashable {
    case app, applications, background, diskIcon
    case extra(UUID)

    var inspectorAnchor: String {
        switch self {
        case .app: "app"
        case .applications: "layout"
        case .background, .diskIcon: "appearance"
        case .extra(let id): "extra-\(id.uuidString)"
        }
    }
}

struct WorkspaceSidebar: View {
    @Bindable var model: PackagingModel
    @Binding var selection: WorkspaceItem?

    var body: some View {
        List(selection: $selection) {
            Section("Image Contents") {
                if let source = model.sourceURL {
                    SidebarFileRow(name: source.lastPathComponent, url: source)
                        .tag(WorkspaceItem.app)
                        .contextMenu {
                            Button("Change App…", action: model.chooseApp).disabled(model.isBuilding)
                            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([source]) }
                        }
                }
                if model.options.includeApplications {
                    Label("Applications", systemImage: "folder.badge.gearshape")
                        .tag(WorkspaceItem.applications)
                        .contextMenu { Button("Remove Link", action: removeApplications).disabled(model.isBuilding) }
                }
                ForEach(model.options.extraItems) { item in
                    SidebarFileRow(name: item.name, url: item.url)
                        .tag(WorkspaceItem.extra(item.id))
                        .contextMenu {
                            Button("Remove") { removeExtra(item.id) }.disabled(model.isBuilding)
                            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([item.url]) }
                        }
                }
            }
            Section("Appearance") {
                Label(backgroundTitle, systemImage: "photo")
                    .tag(WorkspaceItem.background)
                    .contextMenu {
                        Button("Choose Background Image…") { model.chooseImage(forBackground: true) }.disabled(model.isBuilding)
                        Button("Use Default Background") { model.options.background = .automatic }.disabled(model.isBuilding)
                        Button("Remove Background") { model.options.background = .none }.disabled(model.isBuilding)
                    }
                Label(diskIconTitle, systemImage: "externaldrive")
                    .tag(WorkspaceItem.diskIcon)
                    .contextMenu {
                        Button("Choose Disk Icon…") { model.chooseImage(forBackground: false) }.disabled(model.isBuilding)
                        Button("Generate from App") { model.options.diskIcon = .automatic }.disabled(model.isBuilding)
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
                        Button("Add Files…", action: model.addFiles)
                        Button("Add Background Image…") { model.chooseImage(forBackground: true); selection = .background }
                        Button("Add Disk Icon…") { model.chooseImage(forBackground: false); selection = .diskIcon }
                        if !model.options.includeApplications {
                            Button("Add Applications Link") { model.options.includeApplications = true }
                        }
                    } label: { Image(systemName: "plus") }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .help("Add Content or Assets")
                    .disabled(model.isBuilding)
                    Spacer()
                    Button(action: removeSelection) { Image(systemName: "minus") }
                        .buttonStyle(.borderless)
                        .help("Remove Selected Item")
                        .disabled(model.isBuilding || !canRemoveSelection)
                }.padding(.horizontal, 14).padding(.vertical, 10)
            }
        }
        .accessibilityIdentifier("workspaceSidebar")
    }

    private var backgroundTitle: String {
        switch model.options.background {
        case .automatic: String(localized: "Default Background")
        case .custom: model.options.backgroundURL?.lastPathComponent ?? String(localized: "Background Image")
        case .none: String(localized: "No Background")
        }
    }

    private var diskIconTitle: String {
        switch model.options.diskIcon {
        case .automatic: String(localized: "Disk Icon · Automatic")
        case .custom: model.options.diskIconURL?.lastPathComponent ?? String(localized: "Disk Icon")
        case .none: String(localized: "No Disk Icon")
        }
    }

    private var canRemoveSelection: Bool {
        guard let selection else { return false }
        switch selection {
        case .applications, .background, .diskIcon, .extra: return true
        case .app: return false
        }
    }

    private func removeSelection() {
        guard !model.isBuilding, let selection else { return }
        switch selection {
        case .applications: removeApplications()
        case .background: model.options.background = .none
        case .diskIcon: model.options.diskIcon = .none
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
            Text(name).lineLimit(1).truncationMode(.middle)
            Spacer(minLength: 0)
            if !FileManager.default.fileExists(atPath: url.path) {
                Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange).help("File not found. Choose it again in the inspector.")
            }
        }.help(url.path)
    }
}
