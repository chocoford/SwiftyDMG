import AppKit
import SwiftUI

@main
struct SwiftyDMGApp: App {
    @NSApplicationDelegateAdaptor(ApplicationDelegate.self) private var delegate

    var body: some Scene {
        Window("SwiftyDMG", id: "main") {
            ContentView(model: delegate.model, delegate: delegate)
        }
        .defaultSize(width: 400, height: 300)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("选择 App…", action: delegate.chooseApp)
                    .keyboardShortcut("o")
                    .disabled(delegate.model.isBuilding)
            }
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updates: delegate.updates)
            }
            CommandMenu("打包配置") {
                Button("导入配置…", action: delegate.model.importPreset).disabled(delegate.model.isBuilding)
                Button("导出配置…", action: delegate.model.exportPreset)
                Divider()
                Button("恢复默认设置") { delegate.model.options = .init() }.disabled(delegate.model.isBuilding)
            }
        }
        Settings {
            UpdateSettingsView(updates: delegate.updates)
        }
    }
}

@MainActor
final class ApplicationDelegate: NSObject, NSApplicationDelegate {
    let model = PackagingModel()
    let updates = UpdateController()
    var reopenMainWindow: (() -> Void)?
    private(set) weak var mainWindow: NSWindow?

    func registerMainWindow(_ window: NSWindow) {
        mainWindow = window
    }

    func showMainWindow() {
        if let mainWindow {
            if mainWindow.isMiniaturized { mainWindow.deminiaturize(nil) }
            mainWindow.makeKeyAndOrderFront(nil)
        } else {
            // Only ask SwiftUI to open the scene if its window has been closed.
            reopenMainWindow?()
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    func chooseApp() {
        showMainWindow()
        model.chooseApp()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.servicesProvider = self
        NSUpdateDynamicServices()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        receive(urls)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return false
    }

    @objc func createDMG(_ pasteboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        var urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        if urls.isEmpty, let paths = pasteboard.propertyList(forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")) as? [String] {
            urls = paths.map { URL(fileURLWithPath: $0) }
        }
        guard urls.count == 1, urls[0].pathExtension.lowercased() == "app" else {
            error.pointee = "请在 Finder 中选择一个 .app。"
            return
        }
        guard !model.isBuilding else {
            error.pointee = "SwiftyDMG 正在打包，请完成当前任务后重试。"
            return
        }
        receive(urls)
    }

    private func receive(_ urls: [URL]) {
        guard let url = urls.first, !model.isBuilding else { return }
        model.selectApp(url)
        showMainWindow()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard model.isBuilding else { return .terminateNow }
        let alert = NSAlert()
        alert.messageText = "正在创建 DMG"
        alert.informativeText = "请等待当前打包完成后退出，以便安全卸载临时镜像。"
        alert.addButton(withTitle: "继续打包")
        alert.runModal()
        return .terminateCancel
    }
}
