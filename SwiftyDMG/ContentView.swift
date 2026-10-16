import AppKit
import SwiftUI

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
    let delegate: AppDelegate
    let documentTitle: String?
    @State private var presentation = WindowPresentation.welcome
    @State private var inspectorTab = InspectorTab.settings
    @State private var inspectorPresented = true

    init(model: PackagingModel, delegate: AppDelegate, documentTitle: String? = nil) {
        self.model = model
        self.delegate = delegate
        self.documentTitle = documentTitle
        _presentation = State(initialValue: model.sourceURL == nil ? .welcome : .resizing)
    }

    var body: some View {
        ZStack {
            if presentation.presentsEditor {
                WorkspaceView(model: model, inspectorTab: $inspectorTab, inspectorPresented: $inspectorPresented)
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
        .background {
            // Keep the glass visible while the welcome content fades out.
            if !presentation.expandsWindow {
                welcomeBackground
                    .ignoresSafeArea()
            }
        }
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
                    } label: { Label(.localizable(.toolbarInspector), systemImage: "sidebar.right") }
                    .help(String(localizable: .toolbarToggleInspectorHelp))
                    .accessibilityIdentifier("toggleInspectorButton")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { model.startBuild() } label: {
                        if model.isBuilding {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label(.localizable(.toolbarCreateDMG), systemImage: "play.fill")
                        }
                    }
                    .disabled(model.isBuilding)
                    .keyboardShortcut(.return, modifiers: .command)
                    .help(String(localizable: .toolbarCreateDMGHelp))
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
        .alert(.localizable(.dialogOperationFailed), isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button(.localizable(.dialogCopyError), action: copyError)
            Button(.localizable(.generalButtonOK), role: .cancel) {}
        } message: { Text(verbatim: model.errorMessage ?? "") }
        .confirmationDialog(.localizable(.dialogReplaceImage), isPresented: $model.confirmReplacement, titleVisibility: .visible) {
            Button(.localizable(.generalButtonReplace), role: .destructive) { model.startBuild(replaceExisting: true) }
            Button(.localizable(.generalButtonCancel), role: .cancel) {}
        } message: { Text(.localizable(.dialogReplaceImageMessage(model.outputURL?.lastPathComponent ?? "DMG"))) }
    }

    @ViewBuilder
    private var welcomeBackground: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        if #available(macOS 26.0, *) {
            Color.clear
                .glassEffect(.regular, in: shape)
        } else {
            shape.fill(.ultraThinMaterial)
        }
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

#Preview("Open App") {
    ContentView(model: PackagingModel(), delegate: AppDelegate())
        .frame(width: 400, height: 300)
}
