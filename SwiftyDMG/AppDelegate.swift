import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let updates = UpdateController()
    private var createWorkspaceWindow: ((WorkspaceState) -> Void)?
    private var pendingApps: [URL] = []
    private var sessions: [ObjectIdentifier: WorkspaceSession] = [:]

    func registerWorkspace(_ model: PackagingModel, window: NSWindow) {
        let id = ObjectIdentifier(window)
        if sessions[id]?.model === model { return }
        sessions = sessions.filter { $0.value.model != nil }
        sessions[id] = WorkspaceSession(model: model, window: window)
        Task { @MainActor [weak self] in self?.drainPendingApps() }
    }

    func connectWorkspaceCreation(_ action: @escaping (WorkspaceState) -> Void) {
        createWorkspaceWindow = action
        drainPendingApps()
    }

    func newWorkspace() {
        createWorkspaceWindow?(.init())
    }

    func newWorkspaceFromApp() {
        chooseAppForWorkspace(reuseEmptyWindow: false)
    }

    func openApp() {
        chooseAppForWorkspace(reuseEmptyWindow: true)
    }

    private func chooseAppForWorkspace(reuseEmptyWindow: Bool) {
        let panel = NSOpenPanel()
        panel.title = String(localizable: .dialogOpenApp)
        panel.allowedContentTypes = [.applicationBundle]
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        createWorkspace(for: url, reuseEmptyWindow: reuseEmptyWindow)
    }

    private func createWorkspace(for url: URL, reuseEmptyWindow: Bool) {
        let candidate = PackagingModel()
        guard candidate.selectApp(url) else {
            NSApp.presentError(PackagingError.invalid(candidate.errorMessage ?? String(localizable: .errorOpenAppFailed)))
            return
        }
        if reuseEmptyWindow,
           let session = sessions.values.first(where: {
               $0.window?.isVisible == true && $0.model?.sourceURL == nil && $0.model?.isBuilding == false
           }), let model = session.model, let window = session.window {
            model.selectApp(url)
            window.makeKeyAndOrderFront(nil)
        } else if let createWorkspaceWindow {
            createWorkspaceWindow(candidate.workspace)
        } else {
            pendingApps.append(url)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    private func drainPendingApps() {
        guard createWorkspaceWindow != nil, !sessions.isEmpty, !pendingApps.isEmpty else { return }
        let urls = pendingApps
        pendingApps.removeAll()
        for url in urls { createWorkspace(for: url, reuseEmptyWindow: true) }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.servicesProvider = self
        NSUpdateDynamicServices()
    }

    #if SWIFTYDMG_WORKSPACE_SAVING
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool { true }
    #endif

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard !flag else { return true }
        newWorkspace()
        return false
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            if url.pathExtension.lowercased() == "app" {
                createWorkspace(for: url, reuseEmptyWindow: true)
            } else {
                #if SWIFTYDMG_WORKSPACE_SAVING
                NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, error in
                    if let error {
                        Task { @MainActor in NSApp.presentError(error) }
                    }
                }
                #else
                NSApp.presentError(PackagingError.invalid(String(localizable: .errorSelectApp)))
                #endif
            }
        }
    }

    @objc func createDMG(_ pasteboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        var urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        if urls.isEmpty, let paths = pasteboard.propertyList(forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")) as? [String] {
            urls = paths.map { URL(fileURLWithPath: $0) }
        }
        guard urls.count == 1, urls[0].pathExtension.lowercased() == "app" else {
            error.pointee = String(localizable: .errorFinderServiceSelection) as NSString
            return
        }
        createWorkspace(for: urls[0], reuseEmptyWindow: true)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if sessions.values.contains(where: { $0.model?.isBuilding == true }) {
            let alert = NSAlert()
            alert.messageText = String(localizable: .dialogBuildInProgress)
            alert.informativeText = String(localizable: .dialogQuitDuringBuildHelp)
            alert.addButton(withTitle: String(localizable: .dialogContinueBuilding))
            alert.runModal()
            return .terminateCancel
        }
        #if SWIFTYDMG_WORKSPACE_SAVING
        let controller = NSDocumentController.shared
        guard controller.hasEditedDocuments else { return .terminateNow }
        Task { @MainActor in
            controller.reviewUnsavedDocuments(withAlertTitle: nil, cancellable: true, delegate: self,
                didReviewAllSelector: #selector(finishedReviewingDocuments(_:didReviewAll:contextInfo:)), contextInfo: nil)
        }
        return .terminateLater
        #else
        return .terminateNow
        #endif
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
