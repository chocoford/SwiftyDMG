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
            throw PackagingError.invalid("窗口宽度须为 320–4096，高度须为 240–4096。")
        }
        try validatePosition(x: appX, y: appY, name: "App")
        if includeApplications {
            try validatePosition(x: applicationsX, y: applicationsY, name: "Applications")
        }
        for (mode, url, name) in [(background, backgroundURL, "背景图片"), (diskIcon, diskIconURL, "磁盘图标")] {
            if mode == .custom {
                var isDirectory: ObjCBool = false
                guard let url, url.isFileURL,
                      FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
                      !isDirectory.boolValue else {
                    throw PackagingError.invalid("请选择有效的\(name)。")
                }
            }
        }
        if signing == .identity && signingIdentity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw PackagingError.invalid("请填写签名身份名称或 SHA-1。")
        }
        var names: Set<String> = [".ds_store", ".background", ".volumeicon.icns"]
        if includeApplications { names.insert("applications") }
        for item in extraItems {
            guard !item.name.isEmpty, item.name != ".", item.name != "..",
                  !item.name.contains("/"), !item.name.contains(":"), !item.name.contains("\0"),
                  names.insert(item.name.lowercased()).inserted else {
                throw PackagingError.invalid("附加文件名称无效或重复：\(item.name)")
            }
            guard item.url.isFileURL, FileManager.default.fileExists(atPath: item.url.path) else {
                throw PackagingError.invalid("找不到附加文件：\(item.url.path)")
            }
            try validatePosition(x: item.x, y: item.y, name: item.name)
        }
    }

    private func validatePosition(x: Double, y: Double, name: String) throws {
        guard x.isFinite, y.isFinite, (0...windowWidth).contains(x), (0...windowHeight).contains(y) else {
            throw PackagingError.invalid("\(name) 的图标位置须位于窗口范围内。")
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
            throw PackagingError.invalid("请选择包含有效 Info.plist 的 .app。")
        }
        let source = sourceURL.resolvingSymlinksInPath().standardizedFileURL.path
        let output = outputURL.resolvingSymlinksInPath().standardizedFileURL.path
        guard outputURL.isFileURL, outputURL.pathExtension.lowercased() == "dmg",
              !output.hasPrefix(source + "/") else {
            throw PackagingError.invalid("输出须为 App 包以外的 .dmg 文件。")
        }
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: output, isDirectory: &isDirectory) {
            guard !isDirectory.boolValue, replaceExisting else {
                throw PackagingError.invalid("输出已存在，请确认替换或选择其他文件名。")
            }
        }
        for item in options.extraItems where item.name.lowercased() == sourceURL.lastPathComponent.lowercased() {
            throw PackagingError.invalid("附加文件与 App 重名：\(item.name)")
        }
    }
}

enum BuildStage: Int, Sendable {
    case preparing, creating, attaching, background, extras, icon, layout, permissions, detaching, compressing, signing, saving

    var title: String {
        ["准备打包", "创建磁盘镜像", "挂载镜像", "设置背景", "添加文件与链接", "设置磁盘图标", "设置 Finder 布局", "设置文件权限", "卸载镜像", "压缩镜像", "签名镜像", "保存 DMG"][rawValue]
    }
    var fraction: Double { Double(rawValue + 1) / 13 }
}
