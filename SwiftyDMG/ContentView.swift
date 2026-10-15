import AppKit
import SwiftUI

enum InspectorTab: String, CaseIterable, Identifiable {
    case settings, activity
    var id: Self { self }
    var title: String { self == .settings ? "设置" : "构建" }
    var symbol: String { self == .settings ? "slider.horizontal.3" : "list.bullet.rectangle" }
}

private enum WindowPresentation {
    case welcome, hidingWelcome, resizing, showingEditor, editor

    var presentsEditor: Bool { self == .showingEditor || self == .editor }
    var expandsWindow: Bool { self == .resizing || presentsEditor }
    var contentOpacity: Double { self == .welcome || self == .editor ? 1 : 0 }
    var isInteractive: Bool { self == .welcome || self == .editor }
}

struct ContentView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable var model: PackagingModel
    let delegate: ApplicationDelegate
    @State private var presentation = WindowPresentation.welcome
    @State private var inspectorTab = InspectorTab.settings
    @State private var inspectorPresented = true

    var body: some View {
        ZStack {
            if presentation.presentsEditor {
                PackagingWorkspace(model: model, inspectorTab: $inspectorTab, inspectorPresented: $inspectorPresented)
                    .transition(.identity)
                    .task { revealEditor() }
            } else {
                WelcomeView(open: model.chooseApp, select: model.selectApp)
                    .transition(.identity)
            }
        }
        .opacity(presentation.contentOpacity)
        .allowsHitTesting(presentation.isInteractive)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WindowSizing(isEditing: presentation.expandsWindow, reduceMotion: reduceMotion, resolve: delegate.registerMainWindow, onResizeComplete: finishWindowResize))
        .navigationTitle(presentation.presentsEditor ? model.sourceURL?.deletingPathExtension().lastPathComponent ?? "SwiftyDMG" : "SwiftyDMG")
        .toolbar {
            if presentation.presentsEditor {
                ToolbarItem(placement: .navigation) {
                    Button(action: model.chooseApp) { Label("打开 App…", systemImage: "folder") }
                        .disabled(model.isBuilding)
                        .help("打开另一个 App（⌘O）")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        withAnimation { inspectorPresented.toggle() }
                    } label: { Label("检查器", systemImage: "sidebar.right") }
                    .help("显示或隐藏检查器")
                    .accessibilityIdentifier("toggleInspectorButton")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { model.startBuild() } label: {
                        if model.isBuilding {
                            ProgressView()
                        } else {
                            Label("创建 DMG", systemImage: "play.fill")
                        }
                    }
                    .disabled(model.isBuilding)
                    .keyboardShortcut(.return, modifiers: .command)
                    .help("创建 DMG（⌘↩）")
                    .accessibilityIdentifier("createDMGButton")
                }
            }
        }
        .toolbar(presentation.presentsEditor ? .visible : .hidden, for: .windowToolbar)
        .onAppear { delegate.reopenMainWindow = { openWindow(id: "main") } }
        .onOpenURL { model.selectApp($0) }
        .onChange(of: model.sourceURL != nil, initial: true) { _, hasSource in
            beginOpening(hasSource)
        }
        .onChange(of: model.sourceURL) { old, new in
            if old != new { inspectorTab = .settings }
        }
        .onChange(of: model.isBuilding) { _, building in
            if building {
                inspectorTab = .activity
                inspectorPresented = true
            }
        }
        .alert("无法完成操作", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("复制错误", action: copyError)
            Button("好", role: .cancel) {}
        } message: { Text(model.errorMessage ?? "") }
        .confirmationDialog("替换已有 DMG？", isPresented: $model.confirmReplacement, titleVisibility: .visible) {
            Button("替换", role: .destructive) { model.startBuild(replaceExisting: true) }
            Button("取消", role: .cancel) {}
        } message: { Text("打包成功后才会替换 \(model.outputURL?.lastPathComponent ?? "DMG")。") }
    }

    private func beginOpening(_ hasSource: Bool) {
        guard hasSource else {
            setPresentationWithoutAnimation(.welcome)
            return
        }
        guard presentation == .welcome else { return }
        if reduceMotion {
            setPresentationWithoutAnimation(.resizing)
            return
        }
        // The native resize starts only once the welcome content is fully hidden.
        withAnimation(.easeOut(duration: 0.14), completionCriteria: .removed) {
            presentation = .hidingWelcome
        } completion: {
            guard presentation == .hidingWelcome, model.sourceURL != nil else { return }
            setPresentationWithoutAnimation(.resizing)
        }
    }

    private func finishWindowResize(_ isEditing: Bool) {
        guard isEditing, presentation == .resizing else { return }
        // Mount the editor at zero opacity after the window reaches its final size.
        setPresentationWithoutAnimation(.showingEditor)
    }

    private func revealEditor() {
        guard presentation == .showingEditor else { return }
        if reduceMotion {
            setPresentationWithoutAnimation(.editor)
        } else {
            withAnimation(.easeIn(duration: 0.2)) { presentation = .editor }
        }
    }

    private func setPresentationWithoutAnimation(_ next: WindowPresentation) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) { presentation = next }
    }

    private func copyError() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(model.errorMessage ?? "", forType: .string)
    }
}

private struct PackagingWorkspace: View {
    @Bindable var model: PackagingModel
    @Binding var inspectorTab: InspectorTab
    @Binding var inspectorPresented: Bool

    var body: some View {
        PreviewCanvas(options: $model.options, sourceURL: model.sourceURL, isBuilding: model.isBuilding)
            .inspector(isPresented: $inspectorPresented) {
                VStack(spacing: 0) {
                    InspectorTabPicker(selection: $inspectorTab)
                        .padding(12)
                    Divider()
                    if inspectorTab == .settings {
                        PackagingSettingsView(model: model)
                    } else {
                        BuildInspector(model: model)
                    }
                }
                .inspectorColumnWidth(min: 300, ideal: 320, max: 380)
            }
    }
}

private struct InspectorTabPicker: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var selection: InspectorTab
    @Namespace private var selectionAnimation

    var body: some View {
        HStack(spacing: 2) {
            ForEach(InspectorTab.allCases) { tab in
                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                        selection = tab
                    }
                } label: {
                    Label(tab.title, systemImage: tab.symbol)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(selection == tab ? Color.primary : Color.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background {
                            if selection == tab {
                                Capsule()
                                    .fill(Color(nsColor: .controlBackgroundColor))
                                    .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
                                    .matchedGeometryEffect(id: "inspectorSelection", in: selectionAnimation)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
                .accessibilityIdentifier("inspectorTab_\(tab.rawValue)")
            }
        }
        .padding(3)
        .background(.quaternary.opacity(0.5), in: Capsule())
        .accessibilityElement(children: .contain)
        .accessibilityLabel("检查器")
    }
}

#Preview("打开 App") {
    ContentView(model: PackagingModel(defaults: UserDefaults(suiteName: "SwiftyDMG.preview")!), delegate: ApplicationDelegate())
        .frame(width: 400, height: 300)
}
