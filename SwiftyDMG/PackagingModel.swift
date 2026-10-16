import AppKit
import Foundation
import Observation
import UniformTypeIdentifiers

struct BuildLogEntry: Identifiable {
    let id = UUID()
    let elapsed: TimeInterval
    let message: String

    var text: String {
        let milliseconds = max(0, Int(elapsed * 1_000))
        let timestamp = String(format: "%02d:%02d.%03d", milliseconds / 60_000,
                               milliseconds / 1_000 % 60, milliseconds % 1_000)
        return "[\(timestamp)] \(message)"
    }
}

struct BuildLogStep: Identifiable {
    enum Status: Equatable {
        case running, succeeded, failed
    }

    let id = UUID()
    let stage: BuildStage
    let heading: BuildLogEntry
    let startedAt: TimeInterval
    var finishedAt: TimeInterval?
    var status = Status.running
    var entries: [BuildLogEntry] = []

    var text: String {
        ([heading.text] + entries.map(\.text)).joined(separator: "\n")
    }

    func duration(at uptime: TimeInterval) -> TimeInterval {
        max(0, (finishedAt ?? uptime) - startedAt)
    }
}

@MainActor @Observable
final class PackagingModel {
    var workspace: WorkspaceState {
        didSet {
            if workspace != oldValue { onWorkspaceChange?(workspace) }
        }
    }
    var options: PackagingOptions {
        get { workspace.options }
        set { workspace.options = newValue }
    }
    var sourceURL: URL? { workspace.sourceURL }
    var outputURL: URL? { workspace.outputURL }
    var outputName: String {
        get {
            guard let filename = outputURL?.lastPathComponent else { return "" }
            return filename.lowercased().hasSuffix(".dmg") ? String(filename.dropLast(4)) : filename
        }
        set {
            guard !isBuilding, let outputURL,
                  !newValue.contains("/"), !newValue.contains(":"),
                  newValue.rangeOfCharacter(from: .controlCharacters) == nil else { return }
            let name = newValue.lowercased().hasSuffix(".dmg") ? String(newValue.dropLast(4)) : newValue
            guard name != outputName else { return }
            var updated = workspace
            updated.outputURL = outputURL.deletingLastPathComponent().appendingPathComponent(name + ".dmg")
            updated.usesAutomaticOutputName = false
            workspace = updated
        }
    }
    private(set) var isBuilding = false
    private(set) var progress = 0.0
    private(set) var status = String(localizable: .buildStatusReady)
    private(set) var logSteps: [BuildLogStep] = []
    var buildLogText: String { logSteps.map(\.text).joined(separator: "\n\n") }
    private(set) var resultURL: URL?
    var errorMessage: String?
    var confirmReplacement = false
    @ObservationIgnored var onWorkspaceChange: ((WorkspaceState) -> Void)?
    @ObservationIgnored private let packager = Packager.shared

    init(workspace: WorkspaceState = .init()) {
        self.workspace = workspace
        refreshAutomaticOutputName()
    }

    func restoreWorkspace(_ workspace: WorkspaceState) {
        let changedSource = self.workspace.sourceURL != workspace.sourceURL
        self.workspace = workspace
        if changedSource && !isBuilding { resetBuildResult() }
    }

    @discardableResult
    func selectApp(_ url: URL) -> Bool {
        guard !isBuilding else { return false }
        guard url.isFileURL, url.pathExtension.lowercased() == "app" else {
            errorMessage = String(localizable: .errorSelectApp)
            return false
        }
        guard let metadata = NSDictionary(contentsOf: url.appendingPathComponent("Contents/Info.plist")),
              metadata["CFBundleName"] is String || metadata["CFBundleDisplayName"] is String else {
            errorMessage = String(localizable: .errorInvalidAppMetadata)
            return false
        }
        var updated = workspace
        updated.sourceURL = url
        if updated.usesAutomaticOutputName || updated.outputURL == nil {
            let directory = updated.outputURL?.deletingLastPathComponent() ?? url.deletingLastPathComponent()
            updated.outputURL = directory.appendingPathComponent(outputFilename(for: url, metadata: metadata))
        }
        workspace = updated
        resetBuildResult()
        return true
    }

    func refreshAutomaticOutputName() {
        guard !isBuilding, workspace.usesAutomaticOutputName, let sourceURL,
              let metadata = NSDictionary(contentsOf: sourceURL.appendingPathComponent("Contents/Info.plist")) else { return }
        let directory = outputURL?.deletingLastPathComponent() ?? sourceURL.deletingLastPathComponent()
        let refreshed = directory.appendingPathComponent(outputFilename(for: sourceURL, metadata: metadata))
        if workspace.outputURL != refreshed { workspace.outputURL = refreshed }
    }

    func resetOutputName() {
        guard !isBuilding else { return }
        workspace.usesAutomaticOutputName = true
        refreshAutomaticOutputName()
    }

    func resetAppPosition() {
        guard !isBuilding else { return }
        let defaults = PackagingOptions()
        var updated = options
        updated.appX = min(defaults.appX, max(0, updated.windowWidth))
        updated.appY = min(defaults.appY, max(0, updated.windowHeight))
        options = updated
    }

    func resetApplicationsPosition() {
        guard !isBuilding else { return }
        let defaults = PackagingOptions()
        var updated = options
        updated.applicationsX = min(defaults.applicationsX, max(0, updated.windowWidth))
        updated.applicationsY = min(defaults.applicationsY, max(0, updated.windowHeight))
        options = updated
    }

    private func outputFilename(for url: URL, metadata: NSDictionary) -> String {
        let name = metadata["CFBundleDisplayName"] as? String ?? metadata["CFBundleName"] as? String ?? url.deletingPathExtension().lastPathComponent
        let version = metadata["CFBundleShortVersionString"] as? String ?? ""
        let filename = [name, version].filter { !$0.isEmpty }.joined(separator: " ").replacingOccurrences(of: "/", with: "-")
        return filename + ".dmg"
    }

    private func resetBuildResult() {
        resultURL = nil
        errorMessage = nil
        status = String(localizable: .buildStatusReady)
        progress = 0
        logSteps = []
    }

    func chooseApp() {
        let panel = NSOpenPanel()
        panel.title = String(localizable: .dialogSelectApp)
        panel.allowedContentTypes = [.applicationBundle]
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url { selectApp(url) }
    }

    func chooseOutput() {
        let panel = NSSavePanel()
        panel.title = String(localizable: .dialogSaveDMG)
        panel.allowedContentTypes = [UTType(filenameExtension: "dmg") ?? .data]
        panel.nameFieldStringValue = outputURL?.lastPathComponent ?? "Application.dmg"
        panel.directoryURL = outputURL?.deletingLastPathComponent()
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            var updated = workspace
            updated.usesAutomaticOutputName = workspace.usesAutomaticOutputName && url.lastPathComponent == outputURL?.lastPathComponent
            updated.outputURL = url
            workspace = updated
        }
    }

    func chooseImage(forBackground: Bool) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        if panel.runModal() == .OK, let url = panel.url {
            guard NSImage(contentsOf: url)?.isValid == true else {
                errorMessage = String(localizable: .errorInvalidImage)
                return
            }
            if forBackground { options.backgroundURL = url; options.background = .custom }
            else { options.diskIconURL = url; options.diskIcon = .custom }
        }
    }

    func addFiles() {
        let panel = NSOpenPanel()
        panel.title = String(localizable: .dialogAddFiles)
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        if panel.runModal() == .OK {
            options.extraItems += panel.urls.map { ExtraItem(url: $0, x: options.windowWidth / 2, y: options.windowHeight * 0.75) }
        }
    }

    func renameFile(_ id: UUID) {
        guard !isBuilding, let item = options.extraItems.first(where: { $0.id == id }) else { return }
        let nameField = NSTextField(string: item.name)
        nameField.frame = NSRect(x: 0, y: 0, width: 280, height: 24)
        let alert = NSAlert()
        alert.messageText = String(localizable: .dialogRenameFile)
        alert.informativeText = String(localizable: .dialogRenameFileHelp)
        alert.accessoryView = nameField
        alert.addButton(withTitle: String(localizable: .generalButtonRename))
        alert.addButton(withTitle: String(localizable: .generalButtonCancel))
        alert.window.initialFirstResponder = nameField
        guard alert.runModal() == .alertFirstButtonReturn,
              !isBuilding, let index = options.extraItems.firstIndex(where: { $0.id == id }) else { return }
        options.extraItems[index].name = nameField.stringValue
    }

    func replaceFile(_ id: UUID) {
        guard !isBuilding, let item = options.extraItems.first(where: { $0.id == id }) else { return }
        let panel = NSOpenPanel()
        panel.title = String(localizable: .dialogReplaceFile)
        panel.directoryURL = item.url.deletingLastPathComponent()
        panel.canChooseDirectories = true
        guard panel.runModal() == .OK, let url = panel.url,
              !isBuilding, let index = options.extraItems.firstIndex(where: { $0.id == id }) else { return }
        options.extraItems[index].url = url
    }

    func startBuild(replaceExisting: Bool = false) {
        guard !isBuilding else { return }
        refreshAutomaticOutputName()
        guard let sourceURL, let outputURL else { return }
        if !replaceExisting && FileManager.default.fileExists(atPath: outputURL.path) {
            confirmReplacement = true
            return
        }
        let request = PackagingRequest(sourceURL: sourceURL, outputURL: outputURL, options: options, replaceExisting: replaceExisting)
        do { try request.validate() }
        catch { errorMessage = error.localizedDescription; return }
        errorMessage = nil
        resultURL = nil
        progress = 0
        logSteps = []
        isBuilding = true
        status = String(localizable: .buildStagePreparing)
        Task { [self] in
            let started = ProcessInfo.processInfo.systemUptime
            beginLogStep(.preparing, started: started)
            let (events, continuation) = AsyncStream<BuildEvent>.makeStream()
            let build = Task {
                defer { continuation.finish() }
                return try await packager.build(request, onLog: { message in
                    continuation.yield(.output(message))
                }, onProgress: { stage in
                    continuation.yield(.stage(stage))
                })
            }
            // One consumer preserves the received event order and drains the final
            // output before showing success or failure.
            for await event in events {
                switch event {
                case .stage(let stage):
                    status = stage.title
                    progress = max(progress, stage.fraction)
                    beginLogStep(stage, started: started)
                case .output(let message):
                    appendLog(message, started: started)
                }
            }
            do {
                let result = try await build.value
                resultURL = result
                progress = 1
                status = String(localizable: .buildStatusSucceeded)
                appendLog("Saved: \(result.path)", started: started)
                finishLogStep(.succeeded)
            } catch {
                errorMessage = error.localizedDescription
                status = String(localizable: .buildStatusFailed)
                appendLog(error.localizedDescription, started: started)
                finishLogStep(.failed)
            }
            isBuilding = false
        }
    }

    private func beginLogStep(_ stage: BuildStage, started: TimeInterval) {
        if let current = logSteps.last, current.stage == stage, current.status == .running { return }
        let now = ProcessInfo.processInfo.systemUptime
        finishLogStep(.succeeded, at: now)
        logSteps.append(BuildLogStep(stage: stage,
                                     heading: BuildLogEntry(elapsed: now - started, message: stage.title),
                                     startedAt: now))
    }

    private func finishLogStep(_ status: BuildLogStep.Status, at uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        guard let index = logSteps.indices.last, logSteps[index].status == .running else { return }
        logSteps[index].finishedAt = uptime
        logSteps[index].status = status
    }

    private func appendLog(_ message: String, started: TimeInterval) {
        guard let index = logSteps.indices.last else { return }
        logSteps[index].entries.append(BuildLogEntry(elapsed: ProcessInfo.processInfo.systemUptime - started,
                                                   message: message))
    }

    func importPreset() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let preset = try JSONDecoder().decode(PackagingOptions.self, from: Data(contentsOf: url))
            try preset.validate()
            options = preset
        } catch { errorMessage = String(localizable: .errorImportPresetFailed(error.localizedDescription)) }
    }

    func exportPreset() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "SwiftyDMG.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(options).write(to: url, options: .atomic)
        } catch { errorMessage = error.localizedDescription }
    }
}
