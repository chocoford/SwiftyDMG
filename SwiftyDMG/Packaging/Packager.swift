import AppDMG
import Darwin
import Foundation
import hdiutil

/// Rejects overlapping jobs on this packager and publishes only completed images.
actor Packager {
    private var isBuilding = false

    init() {}

    func build(_ request: PackagingRequest, onProgress: @escaping @Sendable (BuildStage) -> Void = { _ in }) async throws -> URL {
        guard !isBuilding else {
            throw PackagingError.invalid("正在创建 DMG，请等待当前任务完成。")
        }
        isBuilding = true
        defer { isBuilding = false }
        try request.validate()
        onProgress(.preparing)
        let fm = FileManager.default
        let directory = request.outputURL.deletingLastPathComponent()
            .appendingPathComponent(".SwiftyDMG-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: directory, withIntermediateDirectories: false)
        let stagedURL = directory.appendingPathComponent(request.outputURL.lastPathComponent)
        let options = request.options
        do {
            let background: AppDMG.DMGBackgroundOption
            switch options.background {
            case .automatic: background = .default
            case .custom: background = .manually(options.backgroundURL!)
            case .none: background = .skip
            }
            let icon: AppDMG.DMGIconOption
            switch options.diskIcon {
            case .automatic: icon = .default
            case .custom: icon = .manually(options.diskIconURL!)
            case .none: icon = .skip
            }
            var appendixes = options.extraItems.map {
                AppDMG.Appendix(name: $0.name, destination: $0.url, type: .file, position: CGPoint(x: $0.x, y: $0.y))
            }
            if options.includeApplications {
                appendixes.insert(.application(position: CGPoint(x: options.applicationsX, y: options.applicationsY)), at: 0)
            }
            _ = try await AppDMG.default.createDMG(
                url: request.sourceURL,
                to: stagedURL,
                backgroundImage: background,
                dmgIcon: icon,
                windowRect: CGRect(x: 200, y: 200, width: options.windowWidth, height: options.windowHeight),
                appIconPos: CGPoint(x: options.appX, y: options.appY),
                appendixes: appendixes,
                codesign: .skip
            ) { status in
                let stage: BuildStage
                switch status {
                case .waiting: stage = .preparing
                case .create: stage = .creating
                case .attach: stage = .attaching
                case .makeBackground: stage = .background
                case .addAppendix: stage = .extras
                case .setIcon: stage = .icon
                case .decorateContent: stage = .layout
                case .modifyPermission, .clean: stage = .permissions
                case .detach: stage = .detaching
                case .compress: stage = .compressing
                case .codesign: return
                }
                onProgress(stage)
            }
            if options.signing != .none {
                onProgress(.signing)
                let identity = try await signingIdentity(for: options)
                _ = try await ProcessExecutor.run("/usr/bin/codesign", arguments: ["--force", "--sign", identity, stagedURL.path])
            }
            onProgress(.saving)
            if request.replaceExisting {
                // Staging shares the destination filesystem: rename replaces atomically.
                let result = stagedURL.path.withCString { source in
                    request.outputURL.path.withCString { destination in Darwin.rename(source, destination) }
                }
                if result != 0 { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
            } else {
                try fm.moveItem(at: stagedURL, to: request.outputURL)
            }
            try? fm.removeItem(at: directory)
            return request.outputURL
        } catch {
            let originalError = error
            // AppDMG doesn't expose its mount handle on failure. Match only our
            // uniquely staged image before detaching; never touch unrelated images.
            do {
                try await detachOwnedImage(stagedURL)
                try fm.removeItem(at: directory)
            } catch {
                throw PackagingError.cleanup("\(originalError.localizedDescription)\n\n临时镜像清理失败：\(error.localizedDescription)\n临时目录：\(directory.path)")
            }
            throw originalError
        }
    }

    private func signingIdentity(for options: PackagingOptions) async throws -> String {
        if options.signing == .identity {
            return options.signingIdentity.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let output = try await ProcessExecutor.run("/usr/bin/security", arguments: ["find-identity", "-v", "-p", "codesigning"])
        let regex = try NSRegularExpression(pattern: #"\s+\d+\)\s+([A-Fa-f0-9]{40})\s+"([^"]+)""#)
        let text = output as NSString
        let identities = regex.matches(in: output, range: NSRange(location: 0, length: text.length)).map {
            (hash: text.substring(with: $0.range(at: 1)), name: text.substring(with: $0.range(at: 2)))
        }
        for prefix in ["Developer ID Application:", "Apple Development:", "Mac Developer:"] {
            if let identity = identities.first(where: { $0.name.hasPrefix(prefix) }) { return identity.hash }
        }
        throw PackagingError.invalid("找不到有效的 Developer ID 或开发签名证书。请指定身份，或选择不签名。")
    }

    private func detachOwnedImage(_ image: URL) async throws {
        let output = try await hdiutil.info(options: [.plist])
        let plist = try PropertyListSerialization.propertyList(from: Data(output.utf8), format: nil) as? [String: Any]
        for entry in plist?["images"] as? [[String: Any]] ?? [] {
            guard let path = entry["image-path"] as? String,
                  URL(fileURLWithPath: path).resolvingSymlinksInPath() == image.resolvingSymlinksInPath() else { continue }
            let entities = entry["system-entities"] as? [[String: Any]] ?? []
            if let device = entities.compactMap({ $0["dev-entry"] as? String }).first {
                try await hdiutil.detach(deviceName: device, force: true)
            }
        }
    }
}
