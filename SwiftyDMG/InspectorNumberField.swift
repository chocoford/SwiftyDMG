import AppKit
import SwiftUI

/// The native container stays mounted while its text editor exists only during editing.
struct InspectorNumberField: View {
    @Binding var value: Double
    let label: LocalizedStringResource
    let range: ClosedRange<Double>
    var defaultValue: Double?
    var resetGeneration = 0

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @State private var isEditing = false
    @State private var localResetGeneration = 0
    @State private var editRequest = 0

    var body: some View {
        InspectorNumberControl(
            value: $value, label: String(localized: label), range: range,
            defaultValue: defaultValue, isEnabled: isEnabled, showsReset: voiceOverEnabled,
            resetGeneration: resetGeneration, localResetGeneration: localResetGeneration,
            editRequest: editRequest, editingChanged: { isEditing = $0 }
        )
        .frame(width: 76, height: 24)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 5))
        .overlay {
            RoundedRectangle(cornerRadius: 5)
                .strokeBorder(isEditing ? Color.accentColor : .clear, lineWidth: 2)
                .allowsHitTesting(false)
        }
        .contextMenu {
            Button("Edit Value") { editRequest += 1 }
            if let defaultValue {
                Button("Reset Value") {
                    localResetGeneration += 1
                    value = min(range.upperBound, max(range.lowerBound, defaultValue.rounded()))
                }
            }
        }
        .onChange(of: range, initial: true) { _, _ in
            let adjusted = value.isFinite
                ? min(range.upperBound, max(range.lowerBound, value.rounded()))
                : range.lowerBound
            if adjusted != value { value = adjusted }
        }
    }
}

private struct InspectorNumberControl: NSViewRepresentable {
    @Binding var value: Double
    let label: String
    let range: ClosedRange<Double>
    let defaultValue: Double?
    let isEnabled: Bool
    let showsReset: Bool
    let resetGeneration: Int
    let localResetGeneration: Int
    let editRequest: Int
    let editingChanged: (Bool) -> Void

    func makeNSView(context: Context) -> NumberControlView { NumberControlView(frame: .zero) }

    func updateNSView(_ view: NumberControlView, context: Context) {
        view.valueChanged = { value = $0 }
        view.editingChanged = { [weak view] editing in
            // Configuration can end an edit during a SwiftUI update. Publish afterward.
            DispatchQueue.main.async {
                guard let view, view.isEditing == editing else { return }
                editingChanged(editing)
            }
        }
        view.configure(value: value, label: label, range: range, defaultValue: defaultValue,
                       enabled: isEnabled, showsReset: showsReset, resetGeneration: resetGeneration,
                       localResetGeneration: localResetGeneration, editRequest: editRequest)
    }

    static func dismantleNSView(_ view: NumberControlView, coordinator: ()) {
        view.valueChanged = nil
        view.editingChanged = nil
        view.finishEditing(commit: false)
    }
}

private final class NumberControlView: NSView, NSTextFieldDelegate, NSGestureRecognizerDelegate {
    var valueChanged: ((Double) -> Void)?
    var editingChanged: ((Bool) -> Void)?
    var isEditing: Bool { editor != nil }

    private let prefix = NSTextField(labelWithString: "")
    private let number = NSTextField(labelWithString: "")
    private let unit = NSTextField(labelWithString: "pt")
    private let resetButton = NSButton()
    private var editor: NSTextField?
    private var isFinishing = false
    private var currentValue: Double = 0
    private var valueRange: ClosedRange<Double> = 0...4096
    private var defaultValue: Double?
    private var enabled = true
    private var alwaysShowsReset = false
    private var prefixHovered = false
    private var prefixTrackingArea: NSTrackingArea?
    private var resetGeneration = 0
    private var localResetGeneration = 0
    private var editRequest = 0
    private var dragOrigin: Double?
    private lazy var pan = NSPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
    private lazy var click = NSClickGestureRecognizer(target: self, action: #selector(handleClick(_:)))

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureText(prefix, numeric: false)
        configureText(number, numeric: true)
        configureText(unit, numeric: false)
        prefix.textColor = .secondaryLabelColor
        unit.textColor = .tertiaryLabelColor
        number.alignment = .right
        addSubview(prefix)
        addSubview(number)
        addSubview(unit)

        resetButton.image = NSImage(systemSymbolName: "arrow.counterclockwise", accessibilityDescription: nil)
        resetButton.imagePosition = .imageOnly
        resetButton.imageScaling = .scaleProportionallyDown
        resetButton.isBordered = false
        resetButton.controlSize = .small
        resetButton.target = self
        resetButton.action = #selector(resetValue)
        resetButton.isHidden = true
        resetButton.toolTip = String(localized: "Reset to Default")
        addSubview(resetButton)

        pan.buttonMask = 1
        click.buttonMask = 1
        pan.delegate = self
        click.delegate = self
        pan.delaysPrimaryMouseButtonEvents = true
        click.delaysPrimaryMouseButtonEvents = true
        addGestureRecognizer(pan)
        addGestureRecognizer(click)
        setAccessibilityElement(true)
        setAccessibilityRole(.textField)
        setAccessibilityHelp(String(localized: "Drag to adjust, or click to enter a value."))
    }

    required init?(coder: NSCoder) { return nil }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { false }
    override var intrinsicContentSize: NSSize { NSSize(width: 76, height: 24) }

    private var prefixSlot: NSRect { NSRect(x: 6, y: 0, width: 12, height: bounds.height) }

    private func configureText(_ field: NSTextField, numeric: Bool) {
        field.isEditable = false
        field.isSelectable = false
        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.controlSize = .small
        field.font = numeric
            ? .monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
            : .systemFont(ofSize: NSFont.smallSystemFontSize)
        field.textColor = .labelColor
        field.usesSingleLineMode = true
        field.maximumNumberOfLines = 1
        field.lineBreakMode = .byClipping
        field.setAccessibilityElement(false)
    }

    func configure(value: Double, label: String, range: ClosedRange<Double>, defaultValue: Double?,
                   enabled: Bool, showsReset: Bool, resetGeneration: Int,
                   localResetGeneration: Int, editRequest: Int) {
        let shouldCancel = self.resetGeneration != resetGeneration
            || self.localResetGeneration != localResetGeneration || !enabled
        self.resetGeneration = resetGeneration
        self.localResetGeneration = localResetGeneration
        self.valueRange = range
        self.defaultValue = defaultValue
        self.enabled = enabled
        self.alwaysShowsReset = showsReset
        pan.isEnabled = enabled
        click.isEnabled = enabled
        if !enabled { dragOrigin = nil }
        if shouldCancel { finishEditing(commit: false) }
        currentValue = clamped(value)
        prefix.stringValue = label
        number.stringValue = formattedValue
        resetButton.isEnabled = enabled
        resetButton.setAccessibilityLabel(String(localized: "Reset \(label)"))
        setAccessibilityLabel(label)
        setAccessibilityValue(formattedValue)
        setAccessibilityEnabled(enabled)
        updateResetVisibility()
        needsLayout = true
        window?.invalidateCursorRects(for: self)
        if self.editRequest != editRequest {
            self.editRequest = editRequest
            DispatchQueue.main.async { [weak self] in
                guard let self, self.editRequest == editRequest else { return }
                self.beginEditing()
            }
        }
    }

    override func layout() {
        super.layout()
        // Use the cells' natural height, rather than an oversized text frame.
        let unitWidth = ceil(unit.intrinsicContentSize.width)
        let unitX = bounds.width - 6 - unitWidth
        let numberX = prefixSlot.maxX + 4
        prefix.frame = centeredRect(x: prefixSlot.minX, width: prefixSlot.width, field: prefix)
        number.frame = centeredRect(x: numberX, width: max(0, unitX - 4 - numberX), field: number)
        unit.frame = centeredRect(x: unitX, width: unitWidth, field: unit)
        resetButton.frame = NSRect(x: prefixSlot.minX, y: (bounds.height - 14) / 2, width: 12, height: 14)
        editor?.frame = number.frame
    }

    private func centeredRect(x: CGFloat, width: CGFloat, field: NSTextField) -> NSRect {
        let height = ceil(field.intrinsicContentSize.height)
        return NSRect(x: x, y: (bounds.height - height) / 2, width: width, height: height)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let localPoint = convert(point, from: superview)
        guard !isHidden, bounds.contains(localPoint) else { return nil }
        if !resetButton.isHidden, resetButton.frame.contains(localPoint) { return resetButton }
        if let editor, editor.frame.contains(localPoint) { return super.hitTest(point) }
        return self
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        guard enabled else { return }
        let start = isEditing ? unit.frame.minX : number.frame.minX
        addCursorRect(NSRect(x: start, y: 0, width: max(0, bounds.width - start), height: bounds.height),
                      cursor: .resizeLeftRight)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let prefixTrackingArea { removeTrackingArea(prefixTrackingArea) }
        let area = NSTrackingArea(rect: prefixSlot, options: [.mouseEnteredAndExited, .activeInKeyWindow],
                                  owner: self, userInfo: nil)
        addTrackingArea(area)
        prefixTrackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        prefixHovered = true
        updateResetVisibility()
    }

    override func mouseExited(with event: NSEvent) {
        prefixHovered = false
        updateResetVisibility()
    }

    private func updateResetVisibility() {
        let showsReset = defaultValue != nil && (prefixHovered || alwaysShowsReset)
        prefix.isHidden = showsReset
        resetButton.isHidden = !showsReset
    }

    func gestureRecognizer(_ gestureRecognizer: NSGestureRecognizer, shouldAttemptToRecognizeWith event: NSEvent) -> Bool {
        guard enabled else { return false }
        let point = convert(event.locationInWindow, from: nil)
        if prefixSlot.contains(point) { return false }
        if let editor, editor.frame.contains(point) { return false }
        return true
    }

    func gestureRecognizer(_ gestureRecognizer: NSGestureRecognizer,
                           shouldRequireFailureOf otherGestureRecognizer: NSGestureRecognizer) -> Bool {
        gestureRecognizer === click && otherGestureRecognizer === pan
    }

    @objc private func handlePan(_ recognizer: NSPanGestureRecognizer) {
        guard enabled else { return }
        switch recognizer.state {
        case .began, .changed, .ended:
            if dragOrigin == nil {
                finishEditing(commit: false)
                dragOrigin = currentValue
            }
            setValue((dragOrigin ?? currentValue) + Double(recognizer.translation(in: self).x))
            if recognizer.state == .ended { dragOrigin = nil }
        case .cancelled, .failed:
            dragOrigin = nil
        default:
            break
        }
    }

    @objc private func handleClick(_ recognizer: NSClickGestureRecognizer) {
        guard recognizer.state == .ended else { return }
        beginEditing()
    }

    private func beginEditing() {
        guard enabled, editor == nil, window != nil else { return }
        layoutSubtreeIfNeeded()
        let field = NSTextField(frame: number.frame)
        configureText(field, numeric: true)
        field.isEditable = true
        field.isSelectable = true
        field.alignment = .right
        field.stringValue = formattedValue
        field.delegate = self
        field.setAccessibilityElement(true)
        field.setAccessibilityLabel(accessibilityLabel())
        editor = field
        number.isHidden = true
        addSubview(field)
        setAccessibilityElement(false)
        // selectText performs the focus handoff itself. Do not focus a second time.
        field.selectText(nil)
        editingChanged?(true)
        window?.invalidateCursorRects(for: self)
    }

    func finishEditing(commit: Bool, resign: Bool = true) {
        guard let field = editor, !isFinishing else { return }
        isFinishing = true
        let submitted = field.currentEditor()?.string ?? field.stringValue
        field.delegate = nil
        if resign, field.currentEditor() != nil { window?.makeFirstResponder(nil) }
        field.removeFromSuperview()
        editor = nil
        number.isHidden = false
        if commit, let parsed = try? Double(submitted, format: .number), parsed.isFinite { setValue(parsed) }
        setAccessibilityElement(true)
        editingChanged?(false)
        window?.invalidateCursorRects(for: self)
        isFinishing = false
    }

    func controlTextDidEndEditing(_ notification: Notification) {
        guard let field = notification.object as? NSTextField, field === editor else { return }
        // A new responder already owns focus here; never clear that responder.
        finishEditing(commit: true, resign: false)
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        guard control === editor else { return false }
        switch commandSelector {
        case #selector(NSResponder.insertNewline(_:)):
            finishEditing(commit: true)
        case #selector(NSResponder.cancelOperation(_:)):
            finishEditing(commit: false)
        default:
            return false
        }
        return true
    }

    @objc private func resetValue() {
        guard enabled, let defaultValue else { return }
        finishEditing(commit: false)
        setValue(defaultValue)
    }

    private var formattedValue: String {
        currentValue.formatted(.number.precision(.fractionLength(0)).grouping(.never))
    }

    private func clamped(_ number: Double) -> Double {
        guard number.isFinite else { return valueRange.lowerBound }
        return min(valueRange.upperBound, max(valueRange.lowerBound, number.rounded()))
    }

    private func setValue(_ value: Double) {
        let adjusted = clamped(value)
        guard adjusted != currentValue else { return }
        currentValue = adjusted
        number.stringValue = formattedValue
        setAccessibilityValue(formattedValue)
        valueChanged?(adjusted)
    }

    override func accessibilityPerformPress() -> Bool {
        guard enabled else { return false }
        beginEditing()
        return true
    }

    override func accessibilityPerformIncrement() -> Bool {
        guard enabled else { return false }
        setValue(currentValue + 1)
        return true
    }

    override func accessibilityPerformDecrement() -> Bool {
        guard enabled else { return false }
        setValue(currentValue - 1)
        return true
    }
}
