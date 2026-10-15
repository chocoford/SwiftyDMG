import Combine
import Foundation
import Sparkle
import SwiftUI

@MainActor
final class UpdateController: ObservableObject {
    @Published private(set) var canCheck = false
    @Published private(set) var automaticChecks = false
    @Published private(set) var automaticDownloads = false
    let isConfigured: Bool
    private let controller: SPUStandardUpdaterController

    init(bundle: Bundle = .main) {
        let key = bundle.object(forInfoDictionaryKey: "SUPublicEDKey") as? String ?? ""
        let feed = bundle.object(forInfoDictionaryKey: "SUFeedURL") as? String ?? ""
        isConfigured = Data(base64Encoded: key)?.count == 32 && URL(string: feed)?.scheme == "https"
        controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil)
        guard isConfigured else { return }
        controller.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: DispatchQueue.main).assign(to: &$canCheck)
        controller.updater.publisher(for: \.automaticallyChecksForUpdates)
            .receive(on: DispatchQueue.main).assign(to: &$automaticChecks)
        controller.updater.publisher(for: \.automaticallyDownloadsUpdates)
            .receive(on: DispatchQueue.main).assign(to: &$automaticDownloads)
        controller.startUpdater()
    }

    func check() { controller.checkForUpdates(nil) }
    func setAutomaticChecks(_ value: Bool) { controller.updater.automaticallyChecksForUpdates = value }
    func setAutomaticDownloads(_ value: Bool) { controller.updater.automaticallyDownloadsUpdates = value }
}

struct CheckForUpdatesView: View {
    @ObservedObject var updates: UpdateController
    var body: some View {
        Button("Check for Updates…", action: updates.check).disabled(!updates.canCheck)
    }
}

struct UpdateSettingsView: View {
    @ObservedObject var updates: UpdateController
    var body: some View {
        Form {
            Section("Software Updates") {
                Toggle("Automatically Check for Updates", isOn: Binding(get: { updates.automaticChecks }, set: updates.setAutomaticChecks))
                Toggle("Automatically Download Updates", isOn: Binding(get: { updates.automaticDownloads }, set: updates.setAutomaticDownloads))
                CheckForUpdatesView(updates: updates)
            }.disabled(!updates.isConfigured)
            if !updates.isConfigured {
                Text("Updates are not enabled in this build.")
                    .foregroundStyle(.secondary)
            }
            Section("Finder Service") {
                Text("Move SwiftyDMG to the Applications folder and launch it once. Then select an app in Finder and choose Services → Create DMG with SwiftyDMG from its context menu.")
                Text("If the service is missing, enable it in System Settings → Keyboard → Keyboard Shortcuts → Services.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 470)
    }
}
