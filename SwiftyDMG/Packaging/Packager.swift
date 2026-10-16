import AppDMG
import Darwin
import Foundation
import hdiutil

enum BuildEvent: Sendable {
    case stage(BuildStage)
    case output(String)
}

/// Rejects overlapping jobs on this packager and publishes only completed images.
actor Packager {
    // AppDMG.default owns mutable progress state, so GUI windows share this gate.
    static let shared = Packager()
    private var isBuilding = false

    init() {}

    func build(
        _ request: PackagingRequest,
        onLog: @escaping @Sendable (String) -> Void = { _ in },
        onProgress: @escaping @Sendable (BuildStage) -> Void = { _ in }
    ) async throws -> URL {
        guard !isBuilding else {
            throw PackagingError.invalid(String(localizable: .errorConcurrentBuild))
        }
        isBuilding = true
        defer { isBuilding = false }
        try request.validate()
        onProgress(.preparing)
        onLog("Source: \(request.sourceURL.path)")
        onLog("Destination: \(request.outputURL.path)")
        onLog("System: \(ProcessInfo.processInfo.operatingSystemVersionString)")
        let fm = FileManager.default
        let directory = request.outputURL.deletingLastPathComponent()
            .appendingPathComponent(".SwiftyDMG-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: directory, withIntermediateDirectories: false)
        onLog("Temporary directory: \(directory.path)")
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
                volumeName: options.resolvedVolumeName(for: request.sourceURL),
                backgroundImage: background,
                dmgIcon: icon,
                windowRect: CGRect(x: 200, y: 200, width: options.windowWidth, height: options.windowHeight),
                appIconPos: CGPoint(x: options.appX, y: options.appY),
                appendixes: appendixes,
                codesign: .skip,
                onLog: onLog
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
                let identity = try await signingIdentity(for: options, onLog: onLog)
                _ = try await ProcessExecutor.run("/usr/bin/codesign", arguments: ["--force", "--sign", identity, stagedURL.path], onLog: onLog)
            }
            onProgress(.saving)
            onLog("Moving completed image: \(stagedURL.path) -> \(request.outputURL.path)")
            if request.replaceExisting {
                // Staging shares the destination filesystem: rename replaces atomically.
                let result = stagedURL.path.withCString { source in
                    request.outputURL.path.withCString { destination in Darwin.rename(source, destination) }
                }
                if result != 0 { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
            } else {
                try fm.moveItem(at: stagedURL, to: request.outputURL)
            }
            do {
                try fm.removeItem(at: directory)
                onLog("Removed temporary directory: \(directory.path)")
            } catch {
                onLog("Warning: unable to remove temporary directory \(directory.path): \(error.localizedDescription)")
            }
            return request.outputURL
        } catch {
            let originalError = error
            // AppDMG doesn't expose its mount handle on failure. Match only our
            // uniquely staged image before detaching; never touch unrelated images.
            do {
                onLog("Build failed: \(originalError.localizedDescription)")
                onLog("Cleaning up temporary image")
                try await detachOwnedImage(stagedURL, onLog: onLog)
                try fm.removeItem(at: directory)
                onLog("Removed temporary directory: \(directory.path)")
            } catch {
                throw PackagingError.cleanup(String(localizable: .errorCleanupFailed(originalError.localizedDescription, error.localizedDescription, directory.path)))
            }
            throw originalError
        }
    }

    private func signingIdentity(for options: PackagingOptions, onLog: @escaping @Sendable (String) -> Void) async throws -> String {
        if options.signing == .identity {
            return options.signingIdentity.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let output = try await ProcessExecutor.run("/usr/bin/security", arguments: ["find-identity", "-v", "-p", "codesigning"], onLog: onLog)
        let regex = try NSRegularExpression(pattern: #"\s+\d+\)\s+([A-Fa-f0-9]{40})\s+"([^"]+)""#)
        let text = output as NSString
        let identities = regex.matches(in: output, range: NSRange(location: 0, length: text.length)).map {
            (hash: text.substring(with: $0.range(at: 1)), name: text.substring(with: $0.range(at: 2)))
        }
        for prefix in ["Developer ID Application:", "Apple Development:", "Mac Developer:"] {
            if let identity = identities.first(where: { $0.name.hasPrefix(prefix) }) { return identity.hash }
        }
        throw PackagingError.invalid(String(localizable: .errorSigningIdentityUnavailable))
    }

    private func detachOwnedImage(_ image: URL, onLog: @escaping @Sendable (String) -> Void) async throws {
        let output = try await hdiutil.info(options: [.plist], onLog: onLog)
        let plist = try PropertyListSerialization.propertyList(from: Data(output.utf8), format: nil) as? [String: Any]
        for entry in plist?["images"] as? [[String: Any]] ?? [] {
            guard let path = entry["image-path"] as? String,
                  URL(fileURLWithPath: path).resolvingSymlinksInPath() == image.resolvingSymlinksInPath() else { continue }
            let entities = entry["system-entities"] as? [[String: Any]] ?? []
            if let device = entities.compactMap({ $0["dev-entry"] as? String }).first {
                try await hdiutil.detach(deviceName: device, force: true, onLog: onLog)
            }
        }
    }
}
