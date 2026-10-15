import Foundation
import XCTest
// The Xcode test target compiles the same packaging sources without launching the GUI.

final class PackagingTests: XCTestCase {
    func testProcessTerminationAfterTaskSuspension() async throws {
        for _ in 0..<50 {
            let output = try await ProcessExecutor.run("/usr/bin/true", arguments: [])
            XCTAssertEqual(output, "")
        }
    }

    func testProcessLaunchFailureDoesNotLeavePipeReadersWaiting() async {
        do {
            _ = try await ProcessExecutor.run("/SwiftyDMG-nonexistent-executable", arguments: [])
            XCTFail("Launching a nonexistent executable must fail")
        } catch {
            XCTAssertFalse(error.localizedDescription.isEmpty)
        }
    }

    func testSuccessfulProcessAllowsWarnings() async throws {
        let output = try await ProcessExecutor.run("/bin/sh", arguments: ["-c", "printf 'success'; printf 'warning' >&2"])
        XCTAssertEqual(output, "success")
    }

    private func fixture() throws -> (directory: URL, app: URL) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("SwiftyDMG Tests \(UUID().uuidString)", isDirectory: true)
        let app = directory.appendingPathComponent("Example App.app", isDirectory: true)
        let contents = app.appendingPathComponent("Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        let metadata = ["CFBundleName": "Example App", "CFBundleShortVersionString": "1.0", "CFBundleVersion": "1"]
        try PropertyListSerialization.data(fromPropertyList: metadata, format: .xml, options: 0)
            .write(to: contents.appendingPathComponent("Info.plist"))
        return (directory, app)
    }

    func testOptionsRoundTrip() throws {
        var options = PackagingOptions()
        options.windowWidth = 800
        options.appX = 220
        options.volumeName = "Example Installer"
        options.signing = .identity
        options.signingIdentity = "Developer ID Application: Example"
        let decoded = try JSONDecoder().decode(PackagingOptions.self, from: JSONEncoder().encode(options))
        XCTAssertEqual(decoded, options)
    }

    func testLegacyOptionsKeepAutomaticVolumeName() throws {
        let data = try JSONEncoder().encode(PackagingOptions())
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        legacy.removeValue(forKey: "volumeName")
        let decoded = try JSONDecoder().decode(PackagingOptions.self, from: JSONSerialization.data(withJSONObject: legacy))
        XCTAssertNil(decoded.volumeName)

        let fixture = try fixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let renamedApp = fixture.directory.appendingPathComponent("Renamed.app")
        try FileManager.default.moveItem(at: fixture.app, to: renamedApp)
        XCTAssertEqual(decoded.resolvedVolumeName(for: renamedApp), "Example App")
    }

    func testRejectsInvalidLayout() {
        var options = PackagingOptions()
        options.windowWidth = .infinity
        XCTAssertThrowsError(try options.validate())
        options.windowWidth = 660
        options.appY = 401
        XCTAssertThrowsError(try options.validate())
    }

    func testRejectsReservedAndTraversalNames() throws {
        let fixture = try fixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        var options = PackagingOptions()
        var item = ExtraItem(url: fixture.app)
        for name in ["Applications", ".DS_Store", "../escape", "folder/file", ".."] {
            item.name = name
            options.extraItems = [item]
            XCTAssertThrowsError(try options.validate(), name)
        }
    }

    func testRejectsOutputInsideApp() throws {
        let fixture = try fixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let request = PackagingRequest(sourceURL: fixture.app, outputURL: fixture.app.appendingPathComponent("recursive.dmg"), options: .init())
        XCTAssertThrowsError(try request.validate())
    }

    func testExistingOutputRequiresConfirmation() throws {
        let fixture = try fixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let output = fixture.directory.appendingPathComponent("existing.dmg")
        try Data("original".utf8).write(to: output)
        XCTAssertThrowsError(try PackagingRequest(sourceURL: fixture.app, outputURL: output, options: .init()).validate())
        XCTAssertNoThrow(try PackagingRequest(sourceURL: fixture.app, outputURL: output, options: .init(), replaceExisting: true).validate())
    }

    func testFullPackagingWithSpacesAndExtraFile() async throws {
        let fixture = try fixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let readme = fixture.directory.appendingPathComponent("Read Me.txt")
        try Data("Hello from SwiftyDMG".utf8).write(to: readme)
        var options = PackagingOptions()
        options.diskIcon = .none
        options.volumeName = "Example Installer"
        options.extraItems = [ExtraItem(url: readme)]
        let output = fixture.directory.appendingPathComponent("Example App.dmg")
        _ = try await Packager().build(.init(sourceURL: fixture.app, outputURL: output, options: options))
        XCTAssertTrue(FileManager.default.fileExists(atPath: output.path))
        _ = try await ProcessExecutor.run("/usr/bin/hdiutil", arguments: ["verify", output.path])
        let plist = try await ProcessExecutor.run("/usr/bin/hdiutil", arguments: ["attach", "-readonly", "-nobrowse", "-plist", output.path])
        let attachment = try PropertyListSerialization.propertyList(from: Data(plist.utf8), format: nil) as! [String: Any]
        let entities = attachment["system-entities"] as! [[String: Any]]
        let mount = URL(fileURLWithPath: entities.compactMap { $0["mount-point"] as? String }.first!)
        let checks = [fixture.app.lastPathComponent, "Applications", ".DS_Store", ".background/dmg-background.tiff", readme.lastPathComponent]
        let present = checks.map { FileManager.default.fileExists(atPath: mount.appendingPathComponent($0).path) }
        let mountedVolumeName = try? mount.resourceValues(forKeys: [.volumeNameKey]).volumeName
        _ = try await ProcessExecutor.run("/usr/bin/hdiutil", arguments: ["detach", mount.path])
        XCTAssertEqual(mountedVolumeName, options.volumeName)
        XCTAssertTrue(present.allSatisfy { $0 }, "Missing image contents: \(zip(checks, present).filter { !$0.1 }.map { $0.0 })")
        XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath: fixture.directory.path).contains { $0.hasPrefix(".SwiftyDMG-") })
    }

    func testSigningFailurePreservesExistingOutputAndCleansStaging() async throws {
        let fixture = try fixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let output = fixture.directory.appendingPathComponent("existing.dmg")
        let original = Data("original image must survive".utf8)
        try original.write(to: output)
        var options = PackagingOptions()
        options.diskIcon = .none
        options.background = .none
        options.signing = .identity
        options.signingIdentity = "SwiftyDMG regression nonexistent signing identity"
        do {
            _ = try await Packager().build(.init(sourceURL: fixture.app, outputURL: output, options: options, replaceExisting: true))
            XCTFail("Signing with a nonexistent identity must fail")
        } catch {
            XCTAssertEqual(try Data(contentsOf: output), original)
        }
        XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath: fixture.directory.path).contains { $0.hasPrefix(".SwiftyDMG-") })
    }
}
