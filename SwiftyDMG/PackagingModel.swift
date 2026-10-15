import AppKit
import Foundation
import Observation
import UniformTypeIdentifiers

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
    var usesAutomaticOutputName: Bool {
        get { workspace.usesAutomaticOutputName }
        set {
            workspace.usesAutomaticOutputName = newValue
            if newValue { refreshAutomaticOutputName() }
        }
    }
    private(set) var isBuilding = false
    private(set) var progress = 0.0
    private(set) var status = String(localized: "Ready")
    private(set) var log: [String] = []
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
            errorMessage = String(localized: "Select a .app bundle.")
            return false
        }
        guard let metadata = NSDictionary(contentsOf: url.appendingPathComponent("Contents/Info.plist")),
              metadata["CFBundleName"] is String || metadata["CFBundleDisplayName"] is String else {
            errorMessage = String(localized: "The app’s Info.plist could not be read. Select a valid macOS app.")
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

    private func outputFilename(for url: URL, metadata: NSDictionary) -> String {
        let name = metadata["CFBundleDisplayName"] as? String ?? metadata["CFBundleName"] as? String ?? url.deletingPathExtension().lastPathComponent
        let version = metadata["CFBundleShortVersionString"] as? String ?? ""
        let filename = [name, version].filter { !$0.isEmpty }.joined(separator: " ").replacingOccurrences(of: "/", with: "-")
        return filename + ".dmg"
    }

    private func resetBuildResult() {
        resultURL = nil
        errorMessage = nil
        status = String(localized: "Ready")
        progress = 0
        log = []
    }

    func chooseApp() {
        let panel = NSOpenPanel()
        panel.title = String(localized: "Select an App")
        panel.allowedContentTypes = [.applicationBundle]
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url { selectApp(url) }
    }

    func chooseOutput() {
        let panel = NSSavePanel()
        panel.title = String(localized: "Save DMG")
        panel.allowedContentTypes = [UTType(filenameExtension: "dmg") ?? .data]
        panel.nameFieldStringValue = outputURL?.lastPathComponent ?? "Application.dmg"
        panel.directoryURL = outputURL?.deletingLastPathComponent()
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            var updated = workspace
            updated.outputURL = url
            updated.usesAutomaticOutputName = false
            workspace = updated
        }
    }

    func chooseImage(forBackground: Bool) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        if panel.runModal() == .OK, let url = panel.url {
            guard NSImage(contentsOf: url)?.isValid == true else {
                errorMessage = String(localized: "The image could not be read. Select a valid image file.")
                return
            }
            if forBackground { options.backgroundURL = url; options.background = .custom }
            else { options.diskIconURL = url; options.diskIcon = .custom }
        }
    }

    func addFiles() {
        let panel = NSOpenPanel()
        panel.title = String(localized: "Add to DMG")
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        if panel.runModal() == .OK {
            options.extraItems += panel.urls.map { ExtraItem(url: $0, x: options.windowWidth / 2, y: options.windowHeight * 0.75) }
        }
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
        log = []
        isBuilding = true
        status = String(localized: "Preparing")
        Task { [self] in
            do {
                let result = try await packager.build(request) { [weak self] stage in
                    Task { @MainActor in
                        guard let self, self.isBuilding else { return }
                        self.status = stage.title
                        self.progress = max(self.progress, stage.fraction)
                        self.log.append(stage.title)
                    }
                }
                resultURL = result
                progress = 1
                status = String(localized: "DMG Created")
                log.append(String(localized: "Saved: \(result.path)"))
            } catch {
                errorMessage = error.localizedDescription
                status = String(localized: "Build Failed")
                log.append(error.localizedDescription)
            }
            isBuilding = false
        }
    }

    func importPreset() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let preset = try JSONDecoder().decode(PackagingOptions.self, from: Data(contentsOf: url))
            try preset.validate()
            options = preset
        } catch { errorMessage = String(localized: "Unable to import preset: \(error.localizedDescription)") }
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
