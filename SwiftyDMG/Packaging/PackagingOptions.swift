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

    func validate() throws {
        guard windowWidth.isFinite, windowHeight.isFinite,
              (320...4096).contains(windowWidth), (240...4096).contains(windowHeight) else {
            throw PackagingError.invalid(String(localized: "Window width must be 320–4096 and height must be 240–4096."))
        }
        try validatePosition(x: appX, y: appY, name: "App")
        if includeApplications {
            try validatePosition(x: applicationsX, y: applicationsY, name: "Applications")
        }
        let assets = [
            (background, backgroundURL, String(localized: "Select a valid background image.")),
            (diskIcon, diskIconURL, String(localized: "Select a valid disk icon."))
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
            throw PackagingError.invalid(String(localized: "Enter a signing identity name or SHA-1."))
        }
        var names: Set<String> = [".ds_store", ".background", ".volumeicon.icns"]
        if includeApplications { names.insert("applications") }
        for item in extraItems {
            guard !item.name.isEmpty, item.name != ".", item.name != "..",
                  !item.name.contains("/"), !item.name.contains(":"), !item.name.contains("\0"),
                  names.insert(item.name.lowercased()).inserted else {
                throw PackagingError.invalid(String(localized: "Invalid or duplicate additional file name: \(item.name)"))
            }
            guard item.url.isFileURL, FileManager.default.fileExists(atPath: item.url.path) else {
                throw PackagingError.invalid(String(localized: "Additional file not found: \(item.url.path)"))
            }
            try validatePosition(x: item.x, y: item.y, name: item.name)
        }
    }

    private func validatePosition(x: Double, y: Double, name: String) throws {
        guard x.isFinite, y.isFinite, (0...windowWidth).contains(x), (0...windowHeight).contains(y) else {
            throw PackagingError.invalid(String(localized: "The icon position for \(name) must be inside the window."))
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
            throw PackagingError.invalid(String(localized: "Select a .app bundle with a valid Info.plist."))
        }
        let source = sourceURL.resolvingSymlinksInPath().standardizedFileURL.path
        let output = outputURL.resolvingSymlinksInPath().standardizedFileURL.path
        guard outputURL.isFileURL, outputURL.pathExtension.lowercased() == "dmg",
              !output.hasPrefix(source + "/") else {
            throw PackagingError.invalid(String(localized: "The output must be a .dmg file outside the app bundle."))
        }
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: output, isDirectory: &isDirectory) {
            guard !isDirectory.boolValue, replaceExisting else {
                throw PackagingError.invalid(String(localized: "The output already exists. Confirm replacement or choose another file name."))
            }
        }
        for item in options.extraItems where item.name.lowercased() == sourceURL.lastPathComponent.lowercased() {
            throw PackagingError.invalid(String(localized: "An additional file has the same name as the app: \(item.name)"))
        }
    }
}

enum BuildStage: Int, Sendable {
    case preparing, creating, attaching, background, extras, icon, layout, permissions, detaching, compressing, signing, saving

    var title: String {
        switch self {
        case .preparing: String(localized: "Preparing")
        case .creating: String(localized: "Creating Disk Image")
        case .attaching: String(localized: "Mounting Image")
        case .background: String(localized: "Setting Background")
        case .extras: String(localized: "Adding Files and Links")
        case .icon: String(localized: "Setting Disk Icon")
        case .layout: String(localized: "Applying Finder Layout")
        case .permissions: String(localized: "Setting Permissions")
        case .detaching: String(localized: "Unmounting Image")
        case .compressing: String(localized: "Compressing Image")
        case .signing: String(localized: "Signing Image")
        case .saving: String(localized: "Saving DMG")
        }
    }
    var fraction: Double { Double(rawValue + 1) / 13 }
}
