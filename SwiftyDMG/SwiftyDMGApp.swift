import AppKit
import SwiftUI

@main
struct SwiftyDMGApp: App {
    @NSApplicationDelegateAdaptor(ApplicationDelegate.self) private var delegate

    var body: some Scene {
        DocumentGroup(newDocument: WorkspaceDocument()) { configuration in
            WorkspaceDocumentView(document: configuration.$document, fileURL: configuration.fileURL, delegate: delegate)
        }
        .defaultSize(width: 400, height: 300)
        .commands {
            WorkspaceCommands(delegate: delegate)
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updates: delegate.updates)
            }
            SidebarCommands()
        }
        Settings {
            UpdateSettingsView(updates: delegate.updates)
        }
    }
}

@MainActor
final class ApplicationDelegate: NSObject, NSApplicationDelegate {
    let updates = UpdateController()
    private var createDocument: ((WorkspaceState) -> Void)?
    private var pendingApps: [URL] = []
    private var sessions: [ObjectIdentifier: WorkspaceSession] = [:]

    func registerWorkspace(_ model: PackagingModel, window: NSWindow) {
        let id = ObjectIdentifier(window)
        if sessions[id]?.model === model { return }
        sessions = sessions.filter { $0.value.model != nil }
        sessions[id] = WorkspaceSession(model: model, window: window)
        Task { @MainActor [weak self] in self?.drainPendingApps() }
    }

    func connectDocumentCreation(_ action: @escaping (WorkspaceState) -> Void) {
        createDocument = action
        drainPendingApps()
    }

    func newWorkspaceFromApp() {
        let panel = NSOpenPanel()
        panel.title = String(localized: "New Workspace from App")
        panel.allowedContentTypes = [.applicationBundle]
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        createWorkspace(for: url, reuseEmptyWindow: false)
    }

    private func createWorkspace(for url: URL, reuseEmptyWindow: Bool) {
        let candidate = PackagingModel()
        guard candidate.selectApp(url) else {
            NSApp.presentError(PackagingError.invalid(candidate.errorMessage ?? String(localized: "Unable to open this app.")))
            return
        }
        if reuseEmptyWindow,
           let session = sessions.values.first(where: {
               $0.window?.isVisible == true && $0.model?.sourceURL == nil && $0.model?.isBuilding == false
           }), let model = session.model, let window = session.window {
            model.selectApp(url)
            window.makeKeyAndOrderFront(nil)
        } else if let createDocument {
            createDocument(candidate.workspace)
        } else {
            pendingApps.append(url)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    private func drainPendingApps() {
        guard createDocument != nil, !sessions.isEmpty, !pendingApps.isEmpty else { return }
        let urls = pendingApps
        pendingApps.removeAll()
        for url in urls { createWorkspace(for: url, reuseEmptyWindow: true) }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.servicesProvider = self
        NSUpdateDynamicServices()
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool { true }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard !flag else { return true }
        NSDocumentController.shared.newDocument(nil)
        return false
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            if url.pathExtension.lowercased() == "app" {
                createWorkspace(for: url, reuseEmptyWindow: true)
            } else {
                NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, error in
                    if let error {
                        Task { @MainActor in NSApp.presentError(error) }
                    }
                }
            }
        }
    }

    @objc func createDMG(_ pasteboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        var urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        if urls.isEmpty, let paths = pasteboard.propertyList(forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")) as? [String] {
            urls = paths.map { URL(fileURLWithPath: $0) }
        }
        guard urls.count == 1, urls[0].pathExtension.lowercased() == "app" else {
            error.pointee = String(localized: "Select one .app in Finder.") as NSString
            return
        }
        createWorkspace(for: urls[0], reuseEmptyWindow: true)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if sessions.values.contains(where: { $0.model?.isBuilding == true }) {
            let alert = NSAlert()
            alert.messageText = String(localized: "Creating DMG")
            alert.informativeText = String(localized: "Wait for the current build to finish before quitting so temporary disk images can be safely unmounted.")
            alert.addButton(withTitle: String(localized: "Continue Building"))
            alert.runModal()
            return .terminateCancel
        }
        let controller = NSDocumentController.shared
        guard controller.hasEditedDocuments else { return .terminateNow }
        Task { @MainActor in
            controller.reviewUnsavedDocuments(withAlertTitle: nil, cancellable: true, delegate: self,
                didReviewAllSelector: #selector(finishedReviewingDocuments(_:didReviewAll:contextInfo:)), contextInfo: nil)
        }
        return .terminateLater
    }

    @objc private func finishedReviewingDocuments(_ controller: NSDocumentController, didReviewAll: Bool, contextInfo: UnsafeMutableRawPointer?) {
        NSApp.reply(toApplicationShouldTerminate: didReviewAll)
    }
}

@MainActor
private final class WorkspaceSession {
    weak var model: PackagingModel?
    weak var window: NSWindow?

    init(model: PackagingModel, window: NSWindow) {
        self.model = model
        self.window = window
    }
}
