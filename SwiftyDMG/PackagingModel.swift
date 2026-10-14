import AppKit
import Foundation
import Observation
import UniformTypeIdentifiers

@MainActor @Observable
final class PackagingModel {
    var options: PackagingOptions { didSet { saveOptions() } }
    private(set) var sourceURL: URL?
    var outputURL: URL?
    private(set) var isBuilding = false
    private(set) var progress = 0.0
    private(set) var status = "准备就绪"
    private(set) var log: [String] = []
    private(set) var resultURL: URL?
    var errorMessage: String?
    var confirmReplacement = false
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let packager = Packager()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: "packagingOptions.v1"),
           let saved = try? JSONDecoder().decode(PackagingOptions.self, from: data) {
            options = saved
        } else { options = .init() }
    }

    func selectApp(_ url: URL) {
        guard !isBuilding else { return }
        guard url.isFileURL, url.pathExtension.lowercased() == "app" else {
            errorMessage = "请选择一个 .app 文件。"
            return
        }
        sourceURL = url
        let metadata = NSDictionary(contentsOf: url.appendingPathComponent("Contents/Info.plist"))
        let name = metadata?["CFBundleDisplayName"] as? String ?? metadata?["CFBundleName"] as? String ?? url.deletingPathExtension().lastPathComponent
        let version = metadata?["CFBundleShortVersionString"] as? String ?? ""
        let filename = [name, version].filter { !$0.isEmpty }.joined(separator: " ").replacingOccurrences(of: "/", with: "-")
        outputURL = url.deletingLastPathComponent().appendingPathComponent(filename + ".dmg")
        resultURL = nil
        errorMessage = nil
        status = "准备就绪"
        progress = 0
        log = []
    }

    func chooseApp() {
        let panel = NSOpenPanel()
        panel.title = "选择要打包的 App"
        panel.allowedContentTypes = [.applicationBundle]
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url { selectApp(url) }
    }

    func chooseOutput() {
        let panel = NSSavePanel()
        panel.title = "保存 DMG"
        panel.allowedContentTypes = [UTType(filenameExtension: "dmg") ?? .data]
        panel.nameFieldStringValue = outputURL?.lastPathComponent ?? "Application.dmg"
        panel.directoryURL = outputURL?.deletingLastPathComponent()
        panel.canCreateDirectories = true
        if panel.runModal() == .OK { outputURL = panel.url }
    }

    func chooseImage(forBackground: Bool) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        if panel.runModal() == .OK, let url = panel.url {
            guard NSImage(contentsOf: url)?.isValid == true else {
                errorMessage = "无法读取这张图片，请选择有效的图片文件。"
                return
            }
            if forBackground { options.backgroundURL = url; options.background = .custom }
            else { options.diskIconURL = url; options.diskIcon = .custom }
        }
    }

    func addFiles() {
        let panel = NSOpenPanel()
        panel.title = "添加到 DMG"
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        if panel.runModal() == .OK {
            options.extraItems += panel.urls.map { ExtraItem(url: $0, x: options.windowWidth / 2, y: options.windowHeight * 0.75) }
        }
    }

    func startBuild(replaceExisting: Bool = false) {
        guard !isBuilding, let sourceURL, let outputURL else { return }
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
        status = "准备打包"
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
                status = "DMG 已创建"
                log.append("已保存：\(result.path)")
            } catch {
                errorMessage = error.localizedDescription
                status = "打包失败"
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
        } catch { errorMessage = "配置无法导入：\(error.localizedDescription)" }
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

    private func saveOptions() {
        if let data = try? JSONEncoder().encode(options) { defaults.set(data, forKey: "packagingOptions.v1") }
    }
}
