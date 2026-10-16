import AppKit
import SwiftUI

/// A Finder service can show progress without activating the app or creating a workspace.
@MainActor
final class QuickBuildPanelController: NSObject, NSWindowDelegate {
    let model: PackagingModel
    var onClose: (() -> Void)?
    private let panel: NSPanel

    init(model: PackagingModel) {
        self.model = model
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 250),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        super.init()
        panel.title = String(localizable: .toolbarCreateDMG)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.isRestorable = false
        panel.isExcludedFromWindowsMenu = true
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.delegate = self
        let hosting = NSHostingController(rootView: QuickBuildProgressView(
            model: model,
            dismiss: { [weak self] in self?.dismiss() }
        ))
        hosting.sizingOptions = [.minSize, .preferredContentSize]
        panel.contentViewController = hosting
        panel.setContentSize(hosting.view.fittingSize)
    }

    func present() {
        model.startBuild()
        panel.center()
        // Do not make the panel key or activate SwiftyDMG; Finder retains focus.
        panel.orderFrontRegardless()
    }

    private func dismiss() {
        guard !model.isBuilding else { return }
        // Borderless panels have no standard close button for performClose(_:).
        panel.close()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        !model.isBuilding
    }

    func windowWillClose(_ notification: Notification) {
        onClose?()
    }
}

private struct QuickBuildProgressView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let model: PackagingModel
    let dismiss: () -> Void

    private var progress: Double { min(max(model.progress, 0), 1) }
    private var percentage: Double { (progress * 100).rounded() }
    private var progressColor: Color {
        model.errorMessage != nil ? .orange : model.resultURL != nil ? .green : .accentColor
    }

    var body: some View {
        Group {
            if #available(macOS 26.0, *) {
                GlassEffectContainer(spacing: 12) {
                    panelContent.buttonStyle(.glass)
                }
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            } else {
                panelContent
                    .buttonStyle(.bordered)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
        }
        .fontDesign(.rounded)
        .buttonBorderShape(.capsule)
        .accessibilityIdentifier("quickBuildProgressPanel")
    }

    private var panelContent: some View {
        VStack(spacing: 20) {
            Text(verbatim: model.sourceURL?.deletingPathExtension().lastPathComponent ?? "SwiftyDMG")
                .font(.callout.weight(.semibold))
                .lineLimit(1)
                .truncationMode(.middle)

            VStack(spacing: 16) {
                Group {
                    if model.errorMessage != nil {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 44, weight: .medium))
                            .foregroundStyle(.orange)
                    } else {
                        Text(progress, format: .percent.precision(.fractionLength(0)))
                            .font(.system(size: 56, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText(value: percentage))
                            .animation(reduceMotion ? nil : .smooth(duration: 0.35), value: percentage)
                    }
                }
                .frame(height: 72)

                VStack(spacing: 12) {
                    QuickBuildProgressBar(value: progress, tint: progressColor)
                    Group {
                        if model.errorMessage != nil {
                            Text(.localizable(.dialogOperationFailed))
                        } else {
                            Text(verbatim: model.status)
                        }
                    }
                    .font(.callout.weight(.medium))
                    .foregroundStyle(model.resultURL != nil ? Color.green : .secondary)
                    .lineLimit(2)
                }
            }

            actions
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 24)
        .frame(width: 360)
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var actions: some View {
        if model.confirmReplacement {
            Text(.localizable(.dialogReplaceImageMessage(model.outputURL?.lastPathComponent ?? "DMG")))
                .font(.callout)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Button(.localizable(.generalButtonCancel), action: dismiss)
                Button(.localizable(.generalButtonReplace), role: .destructive) {
                    model.confirmReplacement = false
                    model.startBuild(replaceExisting: true)
                }
            }
        } else if let error = model.errorMessage {
            Text(verbatim: error)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(4)
                .help(error)
            HStack(spacing: 12) {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(model.buildLogText.isEmpty ? error : model.buildLogText, forType: .string)
                } label: { Image(systemName: "doc.on.doc") }
                .help(String(localizable: .buildCopyEntireLog))
                .accessibilityLabel(.localizable(.buildCopyEntireLog))
                Spacer()
                Button(.localizable(.toolbarCreateDMG)) { model.startBuild() }
                Button(.localizable(.generalButtonOK), action: dismiss)
            }
        } else if let result = model.resultURL {
            HStack(spacing: 12) {
                revealButton(for: result)
                Button(.localizable(.generalButtonOK), action: dismiss)
            }
        }
    }

    @ViewBuilder
    private func revealButton(for result: URL) -> some View {
        if #available(macOS 26.0, *) {
            Button(.localizable(.generalShowInFinder)) {
                NSWorkspace.shared.activateFileViewerSelecting([result])
            }
            .buttonStyle(.glassProminent)
        } else {
            Button(.localizable(.generalShowInFinder)) {
                NSWorkspace.shared.activateFileViewerSelecting([result])
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

private struct QuickBuildProgressBar: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let value: Double
    let tint: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.08))
                Capsule()
                    .fill(tint.gradient)
                    .overlay {
                        Capsule().fill(LinearGradient(
                            colors: [.white.opacity(0.35), .clear],
                            startPoint: .top, endPoint: .bottom
                        ))
                    }
                    .frame(width: geometry.size.width * value)
            }
            .clipShape(Capsule())
            .overlay {
                Capsule().strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
            }
        }
        .frame(height: 10)
        .animation(reduceMotion ? nil : .smooth(duration: 0.35), value: value)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: tint)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(.localizable(.toolbarCreateDMG))
        .accessibilityValue(Text(value, format: .percent.precision(.fractionLength(0))))
    }
}
