import SwiftUI

struct InspectorResetButton: View {
    let title: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) { Label(title, systemImage: "arrow.counterclockwise") }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .controlSize(.small)
            .imageScale(.small)
    }
}

struct InspectorResetLabel: View {
    let title: LocalizedStringKey
    let resetTitle: LocalizedStringKey
    let resetIdentifier: String
    let reset: () -> Void
    var canReset = true

    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @State private var isHovered = false
    @FocusState private var resetFocused: Bool

    private var showsReset: Bool { isHovered || resetFocused || voiceOverEnabled }

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
            InspectorResetButton(title: resetTitle, action: reset)
                .help(resetTitle)
                .disabled(!canReset)
                .focused($resetFocused)
                .opacity(showsReset ? 1 : 0)
                .allowsHitTesting(showsReset)
                .accessibilityIdentifier(resetIdentifier)
        }
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .contextMenu {
            Button(resetTitle, action: reset).disabled(!canReset)
        }
    }
}

struct InspectorInlineRowStyle: LabeledContentStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .center, spacing: 0) {
            configuration.label
                .lineLimit(1)
            Spacer(minLength: 8)
            configuration.content
                .fixedSize(horizontal: true, vertical: false)
        }
    }
}

struct PositionSettingsRow: View {
    let title: LocalizedStringKey
    @Binding var x: Double
    @Binding var y: Double
    let resetTitle: LocalizedStringKey
    let resetIdentifier: String
    let reset: () -> Void
    var maxX: Double
    var maxY: Double
    var defaultX = PackagingOptions().appX
    var defaultY = PackagingOptions().appY
    @State private var resetGeneration = 0

    var body: some View {
        LabeledContent {
            CoordinateFields(first: $x, second: $y,
                             firstRange: 0...maxX, secondRange: 0...maxY,
                             firstDefault: defaultX, secondDefault: defaultY,
                             resetGeneration: resetGeneration)
        } label: {
            InspectorResetLabel(title: title, resetTitle: resetTitle,
                                resetIdentifier: resetIdentifier, reset: {
                                    resetGeneration += 1
                                    reset()
                                })
        }
        .labeledContentStyle(InspectorInlineRowStyle())
    }
}

struct InspectorAssetRow: View {
    let url: URL?
    let action: () -> Void

    var body: some View {
        HStack {
            Text(verbatim: url?.lastPathComponent ?? String(localizable: .generalNotSelected)).font(.caption).lineLimit(1).truncationMode(.middle)
            Spacer()
            Button(.localizable(.generalButtonChoose), action: action)
        }
    }
}

struct CoordinateFields: View {
    @Binding var first: Double
    @Binding var second: Double
    var firstLabel: LocalizedStringResource = .localizable(.inspectorAxisX)
    var secondLabel: LocalizedStringResource = .localizable(.inspectorAxisY)
    var firstRange: ClosedRange<Double> = 0...4096
    var secondRange: ClosedRange<Double> = 0...4096
    var firstDefault: Double?
    var secondDefault: Double?
    var resetGeneration = 0

    var body: some View {
        HStack(spacing: 5) {
            InspectorNumberField(value: $first, label: firstLabel, range: firstRange,
                                 defaultValue: firstDefault, resetGeneration: resetGeneration)
            InspectorNumberField(value: $second, label: secondLabel, range: secondRange,
                                 defaultValue: secondDefault, resetGeneration: resetGeneration)
        }
    }
}
