import AppKit
import SwiftUI

struct OutputSettingsSection: View {
    @Bindable var model: PackagingModel

    private var directoryURL: URL? {
        model.outputURL?.deletingLastPathComponent()
    }

    private var directoryPath: String {
        directoryURL?.path ?? String(localizable: .inspectorNoSaveLocation)
    }

    var body: some View {
        Section(.localizable(.inspectorOutputSection)) {
            LabeledContent {
                HStack(spacing: 8) {
                    TextField(.localizable(.generalFileName), text: $model.outputName)
                        .labelsHidden()
                        .textFieldStyle(.roundedBorder)
                        .help(String(localizable: .inspectorFileExtensionHelp))
                        .accessibilityIdentifier("outputNameField")
                    Text(verbatim: ".dmg").foregroundStyle(.secondary)
                }
            } label: {
                InspectorResetLabel(title: .localizable(.generalFileName), resetTitle: .localizable(.inspectorResetFileName),
                                    resetIdentifier: "resetOutputNameButton", reset: model.resetOutputName,
                                    canReset: model.sourceURL != nil)
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(.localizable(.inspectorSaveLocation)).fontWeight(.medium)
                    Spacer(minLength: 12)
                    Button(.localizable(.generalButtonChange), action: model.chooseOutput)
                }
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "folder")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    Text(verbatim: directoryPath)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                        .help(directoryPath)
                    Button(.localizable(.inspectorOpenSaveLocation), systemImage: "arrow.right.circle.fill") {
                        guard let directoryURL else { return }
                        NSWorkspace.shared.open(directoryURL)
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .font(.callout)
                    .controlSize(.regular)
                    .imageScale(.medium)
                    .help(String(localizable: .inspectorOpenSaveLocation))
                    .disabled(directoryURL == nil)
                    .accessibilityIdentifier("openOutputFolderButton")
                }
            }
            .padding(.vertical, 8)
        }
        .controlSize(.regular)
    }
}
