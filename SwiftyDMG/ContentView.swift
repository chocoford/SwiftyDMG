import AppKit
import SwiftUI

enum InspectorTab: String, CaseIterable, Identifiable {
    case settings, activity
    var id: Self { self }
    var title: LocalizedStringKey { self == .settings ? "Settings" : "Build" }
    var symbol: String { self == .settings ? "slider.horizontal.3" : "list.bullet.rectangle" }
}

private enum WindowPresentation {
    case welcome, hidingWelcome, resizing, loadingEditor, editor

    var presentsEditor: Bool { self == .loadingEditor || self == .editor }
    var presentsWelcome: Bool { self == .welcome || self == .hidingWelcome }
    var expandsWindow: Bool { self == .resizing || presentsEditor }
    var contentOpacity: Double { self == .welcome || self == .editor ? 1 : 0 }
    var isInteractive: Bool { self == .welcome || self == .editor }
}

struct ContentView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable var model: PackagingModel
    let delegate: ApplicationDelegate
    let documentTitle: String?
    @State private var presentation = WindowPresentation.welcome
    @State private var inspectorTab = InspectorTab.settings
    @State private var inspectorPresented = true

    init(model: PackagingModel, delegate: ApplicationDelegate, documentTitle: String? = nil) {
        self.model = model
        self.delegate = delegate
        self.documentTitle = documentTitle
        _presentation = State(initialValue: model.sourceURL == nil ? .welcome : .resizing)
    }

    var body: some View {
        ZStack {
            if presentation.presentsEditor {
                PackagingWorkspace(model: model, inspectorTab: $inspectorTab, inspectorPresented: $inspectorPresented)
                    .transition(.identity)
                    .task { revealEditor() }
            } else if presentation.presentsWelcome {
                WelcomeView(open: model.chooseApp, select: model.selectApp)
                    .transition(.identity)
            } else {
                // Keep the window empty until its native resize completes.
                Color.clear
            }
        }
        .opacity(presentation.contentOpacity)
        .allowsHitTesting(presentation.isInteractive)
        .accessibilityHidden(!presentation.isInteractive)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WindowSizing(
            isEditing: presentation.expandsWindow,
            reduceMotion: reduceMotion,
            resolve: { delegate.registerWorkspace(model, window: $0) },
            onResizeComplete: finishWindowResize
        ))
        .navigationTitle(presentation.presentsEditor ? documentTitle ?? model.sourceURL?.deletingPathExtension().lastPathComponent ?? "SwiftyDMG" : "SwiftyDMG")
        .toolbar {
            if presentation.presentsEditor {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        withAnimation { inspectorPresented.toggle() }
                    } label: { Label("Inspector", systemImage: "sidebar.right") }
                    .help("Show or Hide Inspector")
                    .accessibilityIdentifier("toggleInspectorButton")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { model.startBuild() } label: {
                        if model.isBuilding {
                            ProgressView()
                        } else {
                            Label("Create DMG", systemImage: "play.fill")
                        }
                    }
                    .disabled(model.isBuilding)
                    .keyboardShortcut(.return, modifiers: .command)
                    .help("Create DMG (⌘↩)")
                    .accessibilityIdentifier("createDMGButton")
                }
            }
        }
        .toolbar(presentation.presentsEditor ? .visible : .hidden, for: .windowToolbar)
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
        .alert("Unable to Complete Operation", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("Copy Error", action: copyError)
            Button("OK", role: .cancel) {}
        } message: { Text(model.errorMessage ?? "") }
        .confirmationDialog("Replace Existing DMG?", isPresented: $model.confirmReplacement, titleVisibility: .visible) {
            Button("Replace", role: .destructive) { model.startBuild(replaceExisting: true) }
            Button("Cancel", role: .cancel) {}
        } message: { Text("\(model.outputURL?.lastPathComponent ?? "DMG") will be replaced only after the build succeeds.") }
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
        // Finish the welcome fade before resizing the empty native window.
        withAnimation(.easeOut(duration: 0.14), completionCriteria: .removed) {
            presentation = .hidingWelcome
        } completion: {
            guard presentation == .hidingWelcome, model.sourceURL != nil else { return }
            setPresentationWithoutAnimation(.resizing)
        }
    }

    private func finishWindowResize(_ isEditing: Bool) {
        guard isEditing, presentation == .resizing else { return }
        // Build the editor only once the window has reached its final size.
        setPresentationWithoutAnimation(.loadingEditor)
    }

    private func revealEditor() {
        guard presentation == .loadingEditor else { return }
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
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var selection: WorkspaceItem? = .app

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            WorkspaceSidebar(model: model, selection: $selection)
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 300)
        } detail: {
            PreviewCanvas(options: $model.options, sourceURL: model.sourceURL, isBuilding: model.isBuilding)
        }
        .inspector(isPresented: $inspectorPresented) {
            VStack(spacing: 0) {
                InspectorTabPicker(selection: $inspectorTab)
                    .padding(12)
                Divider()
                if inspectorTab == .settings {
                    PackagingSettingsView(model: model, selection: selection)
                } else {
                    BuildInspector(model: model)
                }
            }
            .inspectorColumnWidth(min: 300, ideal: 320, max: 380)
        }
        .onChange(of: selection) { _, selected in
            if selected != nil {
                inspectorTab = .settings
                inspectorPresented = true
            }
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
        .accessibilityLabel("Inspector")
    }
}

#Preview("Open App") {
    ContentView(model: PackagingModel(), delegate: ApplicationDelegate())
        .frame(width: 400, height: 300)
}
