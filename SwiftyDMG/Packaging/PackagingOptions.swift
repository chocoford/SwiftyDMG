import Foundation

enum AssetMode: String, Codable, CaseIterable, Sendable {
    case automatic, custom, none
}

enum SigningMode: String, Codable, CaseIterable, Sendable {
    case none, automatic, identity
}

struct ExtraItem: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var url: URL
    var name: String
    var x: Double
    var y: Double

    init(url: URL, x: Double = 330, y: Double = 290) {
        self.url = url
        self.name = url.lastPathComponent
        self.x = x
        self.y = y
    }
}

struct PackagingOptions: Codable, Equatable, Sendable {
    var background: AssetMode = .automatic
    var backgroundURL: URL?
    var diskIcon: AssetMode = .automatic
    var diskIconURL: URL?
    var volumeName: String?
    var windowWidth: Double = 660
    var windowHeight: Double = 400
    var appX: Double = 180
    var appY: Double = 170
    var includeApplications = true
    var applicationsX: Double = 480
    var applicationsY: Double = 170
    var signing: SigningMode = .none
    var signingIdentity = ""
    var extraItems: [ExtraItem] = []

    init() {}

    static func defaultVolumeName(for sourceURL: URL?) -> String {
        guard let sourceURL else { return String(localizable: .defaultVolumeName) }
        let metadata = NSDictionary(contentsOf: sourceURL.appendingPathComponent("Contents/Info.plist"))
        return metadata?["CFBundleDisplayName"] as? String
            ?? metadata?["CFBundleName"] as? String
            ?? sourceURL.deletingPathExtension().lastPathComponent
    }

    func resolvedVolumeName(for sourceURL: URL?) -> String {
        let customName = volumeName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return customName.isEmpty ? Self.defaultVolumeName(for: sourceURL) : customName
    }

    func validate() throws {
        if let volumeName {
            guard !volumeName.contains("/"), !volumeName.contains(":"),
                  volumeName.rangeOfCharacter(from: .controlCharacters) == nil else {
                throw PackagingError.invalid(String(localizable: .errorInvalidVolumeName))
            }
        }
        guard windowWidth.isFinite, windowHeight.isFinite,
              (320...4096).contains(windowWidth), (240...4096).contains(windowHeight) else {
            throw PackagingError.invalid(String(localizable: .errorInvalidWindowSize))
        }
        try validatePosition(x: appX, y: appY, name: String(localizable: .generalApp))
        if includeApplications {
            try validatePosition(x: applicationsX, y: applicationsY, name: String(localizable: .sidebarApplications))
        }
        let assets = [
            (background, backgroundURL, String(localizable: .errorSelectBackground)),
            (diskIcon, diskIconURL, String(localizable: .errorSelectDiskIcon))
        ]
        for (mode, url, message) in assets {
            if mode == .custom {
                var isDirectory: ObjCBool = false
                guard let url, url.isFileURL,
                      FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
                      !isDirectory.boolValue else {
                    throw PackagingError.invalid(message)
                }
            }
        }
        if signing == .identity && signingIdentity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw PackagingError.invalid(String(localizable: .errorEmptySigningIdentity))
        }
        var names: Set<String> = [".ds_store", ".background", ".volumeicon.icns"]
        if includeApplications { names.insert("applications") }
        for item in extraItems {
            guard !item.name.isEmpty, item.name != ".", item.name != "..",
                  !item.name.contains("/"), !item.name.contains(":"), !item.name.contains("\0"),
                  names.insert(item.name.lowercased()).inserted else {
                throw PackagingError.invalid(String(localizable: .errorInvalidAdditionalFileName(item.name)))
            }
            guard item.url.isFileURL, FileManager.default.fileExists(atPath: item.url.path) else {
                throw PackagingError.invalid(String(localizable: .errorAdditionalFileMissing(item.url.path)))
            }
            try validatePosition(x: item.x, y: item.y, name: item.name)
        }
    }

    private func validatePosition(x: Double, y: Double, name: String) throws {
        guard x.isFinite, y.isFinite, (0...windowWidth).contains(x), (0...windowHeight).contains(y) else {
            throw PackagingError.invalid(String(localizable: .errorIconOutsideWindow(name)))
        }
    }
}

enum PackagingError: LocalizedError {
    case invalid(String)
    case process(String)
    case cleanup(String)

    var errorDescription: String? {
        switch self {
        case .invalid(let message), .process(let message), .cleanup(let message): return message
        }
    }
}

struct PackagingRequest: Sendable {
    let sourceURL: URL
    let outputURL: URL
    let options: PackagingOptions
    let replaceExisting: Bool

    init(sourceURL: URL, outputURL: URL, options: PackagingOptions, replaceExisting: Bool = false) {
        self.sourceURL = sourceURL
        self.outputURL = outputURL
        self.options = options
        self.replaceExisting = replaceExisting
    }

    func validate() throws {
        try options.validate()
        guard sourceURL.isFileURL, sourceURL.pathExtension.lowercased() == "app",
              let metadata = NSDictionary(contentsOf: sourceURL.appendingPathComponent("Contents/Info.plist")),
              let name = metadata["CFBundleDisplayName"] as? String ?? metadata["CFBundleName"] as? String,
              !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PackagingError.invalid(String(localizable: .errorInvalidAppBundle))
        }
        let source = sourceURL.resolvingSymlinksInPath().standardizedFileURL.path
        let output = outputURL.resolvingSymlinksInPath().standardizedFileURL.path
        let filename = outputURL.lastPathComponent
        if filename.lowercased().hasSuffix(".dmg"),
           String(filename.dropLast(4)).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw PackagingError.invalid(String(localizable: .errorEmptyOutputName))
        }
        guard outputURL.isFileURL, outputURL.pathExtension.lowercased() == "dmg",
              !output.hasPrefix(source + "/") else {
            throw PackagingError.invalid(String(localizable: .errorInvalidOutputLocation))
        }
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: output, isDirectory: &isDirectory) {
            guard !isDirectory.boolValue, replaceExisting else {
                throw PackagingError.invalid(String(localizable: .errorOutputAlreadyExists))
            }
        }
        for item in options.extraItems where item.name.lowercased() == sourceURL.lastPathComponent.lowercased() {
            throw PackagingError.invalid(String(localizable: .errorAdditionalFileMatchesApp(item.name)))
        }
    }
}

enum BuildStage: Int, Sendable {
    case preparing, creating, attaching, background, extras, icon, layout, permissions, detaching, compressing, signing, saving

    var title: String {
        switch self {
        case .preparing: String(localizable: .buildStagePreparing)
        case .creating: String(localizable: .buildStageCreating)
        case .attaching: String(localizable: .buildStageMounting)
        case .background: String(localizable: .buildStageBackground)
        case .extras: String(localizable: .buildStageFiles)
        case .icon: String(localizable: .buildStageIcon)
        case .layout: String(localizable: .buildStageLayout)
        case .permissions: String(localizable: .buildStagePermissions)
        case .detaching: String(localizable: .buildStageUnmounting)
        case .compressing: String(localizable: .buildStageCompressing)
        case .signing: String(localizable: .buildStageSigning)
        case .saving: String(localizable: .buildStageSaving)
        }
    }
    var fraction: Double { Double(rawValue + 1) / 13 }
}
