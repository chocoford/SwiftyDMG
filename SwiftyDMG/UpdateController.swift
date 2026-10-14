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
        Button("检查更新…", action: updates.check).disabled(!updates.canCheck)
    }
}

struct UpdateSettingsView: View {
    @ObservedObject var updates: UpdateController
    var body: some View {
        Form {
            Section("软件更新") {
                Toggle("自动检查更新", isOn: Binding(get: { updates.automaticChecks }, set: updates.setAutomaticChecks))
                Toggle("自动下载更新", isOn: Binding(get: { updates.automaticDownloads }, set: updates.setAutomaticDownloads))
                CheckForUpdatesView(updates: updates)
            }.disabled(!updates.isConfigured)
            if !updates.isConfigured {
                Text("此版本尚未启用更新服务。")
                    .foregroundStyle(.secondary)
            }
            Section("Finder 服务") {
                Text("将 SwiftyDMG 放入应用程序文件夹并启动一次。之后在 Finder 选中 App，通过右键菜单的「服务 → 用 SwiftyDMG 打包」打开。")
                Text("若未显示，可在系统设置 → 键盘 → 键盘快捷键 → 服务中启用。")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 470)
    }
}
