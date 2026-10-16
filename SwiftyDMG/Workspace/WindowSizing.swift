import AppKit
import SwiftUI

/// Keeps the launch and editor stages in the same native window.
struct WindowSizing: NSViewRepresentable {
    static let editorContentSize = NSSize(width: 1280, height: 780)

    let isEditing: Bool
    let reduceMotion: Bool
    let resolve: (NSWindow) -> Void
    let onResizeComplete: (Bool) -> Void

    func makeNSView(context: Context) -> SizingView {
        let view = SizingView()
        configure(view)
        return view
    }

    func updateNSView(_ view: SizingView, context: Context) {
        configure(view)
    }

    @MainActor
    private func configure(_ view: SizingView) {
        view.configure(isEditing: isEditing, reduceMotion: reduceMotion,
                       resolve: resolve, onResizeComplete: onResizeComplete)
    }

    final class SizingView: NSView {
        private var isEditing = false
        private var reduceMotion = false
        private var appliedStage: Bool?
        private var resolve: ((NSWindow) -> Void)?
        private var onResizeComplete: ((Bool) -> Void)?

        func configure(isEditing: Bool, reduceMotion: Bool, resolve: @escaping (NSWindow) -> Void,
                       onResizeComplete: @escaping (Bool) -> Void) {
            self.isEditing = isEditing
            self.reduceMotion = reduceMotion
            self.resolve = resolve
            self.onResizeComplete = onResizeComplete
            applyStage()
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            applyStage()
        }

        private func applyStage() {
            guard let window else { return }
            resolve?(window)
            guard appliedStage != isEditing else { return }
            let firstAppearance = appliedStage == nil
            appliedStage = isEditing
            if firstAppearance { window.styleMask.insert(.fullSizeContentView) }
            applyWindowChrome(window)
            let preferred = isEditing ? WindowSizing.editorContentSize : NSSize(width: 400, height: 300)
            let available = window.screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
            let minimum = isEditing ? NSSize(width: 1080, height: 600) : NSSize(width: 400, height: 300)
            // Raising the minimum before expanding can force an immediate resize.
            // Apply the editor's minimum once the animated expansion has completed.
            if firstAppearance || !isEditing {
                window.contentMinSize = NSSize(width: min(minimum.width, available.width), height: min(minimum.height, available.height))
            }
            // Keep the welcome window compact even if macOS restores an editor-sized frame.
            // Release the limit before animating into the editor.
            window.contentMaxSize = isEditing
                ? NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
                : preferred
            var frame = window.frameRect(forContentRect: NSRect(origin: .zero, size: preferred))
            frame.size.width = min(frame.width, available.width)
            frame.size.height = min(frame.height, available.height)
            frame.origin = NSPoint(x: window.frame.midX - frame.width / 2, y: window.frame.midY - frame.height / 2)
            frame.origin.x = min(max(frame.minX, available.minX), available.maxX - frame.width)
            frame.origin.y = min(max(frame.minY, available.minY), available.maxY - frame.height)
            let stage = isEditing
            NSAnimationContext.runAnimationGroup { context in
                context.duration = reduceMotion || firstAppearance ? 0 : 0.35
                window.animator().setFrame(frame, display: true)
            } completionHandler: { [weak self, weak window] in
                Task { @MainActor in
                    guard let self, let window, self.appliedStage == stage else { return }
                    window.contentMinSize = NSSize(width: min(minimum.width, available.width), height: min(minimum.height, available.height))
                    // Mount the editor after expansion so its initial layout
                    // cannot interrupt the native frame animation.
                    self.onResizeComplete?(stage)
                }
            }
        }

        private func applyWindowChrome(_ window: NSWindow) {
            // Keep the same window style in both stages; only reveal its chrome.
            window.isOpaque = isEditing
            window.backgroundColor = isEditing ? .windowBackgroundColor : .clear
            window.titleVisibility = isEditing ? .visible : .hidden
            window.titlebarAppearsTransparent = !isEditing
            window.titlebarSeparatorStyle = isEditing ? .automatic : .none
            window.isMovableByWindowBackground = !isEditing
            window.toolbar?.isVisible = isEditing
            // Keep the native close control available in the welcome stage.
            window.standardWindowButton(.closeButton)?.isHidden = false
            let buttons: [NSWindow.ButtonType] = [.miniaturizeButton, .zoomButton]
            for button in buttons {
                window.standardWindowButton(button)?.isHidden = !isEditing
            }
        }
    }
}
