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
            Button(.localizable(.inspectorEditValue)) { editRequest += 1 }
            if let defaultValue {
                Button(.localizable(.inspectorResetValue)) {
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
