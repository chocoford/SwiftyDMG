import AppKit
import AppDMG
import SwiftUI
import UniformTypeIdentifiers

struct PackagingSettingsView: View {
    @Bindable var model: PackagingModel
    var selection: WorkspaceItem? = nil

    var body: some View {
        ScrollViewReader { proxy in
            Form {
                OutputSettingsSection(model: model)
                Section(.localizable(.inspectorAppearanceSection)) {
                    Picker(.localizable(.inspectorBackground), selection: $model.options.background) {
                        Text(.localizable(.inspectorDefaultBackground)).tag(AssetMode.automatic)
                        Text(.localizable(.inspectorCustomImage)).tag(AssetMode.custom)
                        Text(.localizable(.inspectorNoBackground)).tag(AssetMode.none)
                    }
                    if model.options.background == .custom {
                        InspectorAssetRow(url: model.options.backgroundURL) { model.chooseImage(forBackground: true) }
                    }
                    DiskIconSettingsRow(model: model)
                }
                Section(.localizable(.inspectorFinderWindowSection)) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(.localizable(.inspectorVolumeName)).fontWeight(.medium)
                        TextField(.localizable(.inspectorVolumeName), text: Binding(
                            get: { model.options.volumeName ?? "" },
                            set: { model.options.volumeName = $0.isEmpty ? nil : $0 }
                        ), prompt: Text(verbatim: PackagingOptions.defaultVolumeName(for: model.sourceURL)))
                        .labelsHidden()
                        .textFieldStyle(.roundedBorder)
                        .help(String(localizable: .inspectorVolumeNameHelp))
                        .accessibilityIdentifier("volumeNameField")
                    }
                    .controlSize(.regular)
                    .padding(.bottom, 8)
                    LabeledContent(.localizable(.inspectorWindowSize)) {
                        CoordinateFields(
                            first: $model.options.windowWidth, second: $model.options.windowHeight,
                            firstLabel: .localizable(.inspectorAxisWidth), secondLabel: .localizable(.inspectorAxisHeight),
                            firstRange: 320...4096, secondRange: 240...4096,
                            firstDefault: PackagingOptions().windowWidth, secondDefault: PackagingOptions().windowHeight
                        )
                    }
                    .labeledContentStyle(InspectorInlineRowStyle())
                    #if SWIFTYDMG_SIDEBAR
                    selectedItemPosition
                    #else
                    PositionSettingsRow(
                        title: .localizable(.inspectorAppPosition), x: $model.options.appX, y: $model.options.appY,
                        resetTitle: .localizable(.inspectorResetAppPosition), resetIdentifier: "resetAppPositionButton",
                        reset: model.resetAppPosition,
                        maxX: model.options.windowWidth, maxY: model.options.windowHeight
                    )
                    Toggle(.localizable(.inspectorApplicationsLink), isOn: $model.options.includeApplications)
                    if model.options.includeApplications {
                        PositionSettingsRow(
                            title: .localizable(.inspectorLinkPosition), x: $model.options.applicationsX, y: $model.options.applicationsY,
                            resetTitle: .localizable(.inspectorResetLinkPosition), resetIdentifier: "resetLinkPositionButton",
                            reset: model.resetApplicationsPosition,
                            maxX: model.options.windowWidth, maxY: model.options.windowHeight,
                            defaultX: PackagingOptions().applicationsX, defaultY: PackagingOptions().applicationsY
                        )
                    }
                    #endif
                }.id("layout")
                #if !SWIFTYDMG_SIDEBAR && SWIFTYDMG_ADDITIONAL_FILES
                AdditionalFilesSettingsSection(model: model)
                #endif
                #if SWIFTYDMG_DMG_SIGNING
                Section(.localizable(.inspectorSigningSection)) {
                    Picker(.localizable(.inspectorSigning), selection: $model.options.signing) {
                        Text(.localizable(.generalNone)).tag(SigningMode.none)
                        Text(.localizable(.inspectorAutomaticSigning)).tag(SigningMode.automatic)
                        Text(.localizable(.inspectorSpecificSigningIdentity)).tag(SigningMode.identity)
                    }
                    if model.options.signing == .identity {
                        TextField(.localizable(.inspectorSigningIdentityPlaceholder), text: $model.options.signingIdentity)
                    }
                    Text(.localizable(.inspectorSigningHelp)).font(.caption).foregroundStyle(.secondary)
                }
                #endif
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .controlSize(.small)
            .disabled(model.isBuilding)
            .onChange(of: selection) { _, selected in
                if selected != nil { proxy.scrollTo("layout", anchor: .top) }
            }
        }
    }

    @ViewBuilder
    private var selectedItemPosition: some View {
        switch selection {
        case .app:
            PositionSettingsRow(
                title: .localizable(.generalPosition), x: $model.options.appX, y: $model.options.appY,
                resetTitle: .localizable(.inspectorResetAppPosition), resetIdentifier: "resetAppPositionButton",
                reset: model.resetAppPosition,
                maxX: model.options.windowWidth, maxY: model.options.windowHeight
            )
        case .applications:
            if model.options.includeApplications {
                PositionSettingsRow(
                    title: .localizable(.generalPosition), x: $model.options.applicationsX, y: $model.options.applicationsY,
                    resetTitle: .localizable(.inspectorResetLinkPosition), resetIdentifier: "resetLinkPositionButton",
                    reset: model.resetApplicationsPosition,
                    maxX: model.options.windowWidth, maxY: model.options.windowHeight,
                    defaultX: PackagingOptions().applicationsX, defaultY: PackagingOptions().applicationsY
                )
            }
        case .extra(let id):
            ForEach($model.options.extraItems) { $item in
                if item.id == id {
                    LabeledContent(.localizable(.generalPosition)) {
                        CoordinateFields(first: $item.x, second: $item.y,
                                         firstRange: 0...model.options.windowWidth, secondRange: 0...model.options.windowHeight)
                    }
                    .labeledContentStyle(InspectorInlineRowStyle())
                }
            }
        case nil:
            EmptyView()
        }
    }
}

private struct DiskIconSettingsRow: View {
    @Bindable var model: PackagingModel
    @State private var preview: NSImage?
    @State private var previewError: String?

    private struct PreviewRequest: Equatable {
        let sourceURL: URL?
        let mode: AssetMode
        let customURL: URL?
    }

    private var request: PreviewRequest {
        PreviewRequest(sourceURL: model.sourceURL, mode: model.options.diskIcon, customURL: model.options.diskIconURL)
    }

    var body: some View {
        VStack(spacing: 8) {
            Picker(.localizable(.inspectorDiskIcon), selection: $model.options.diskIcon) {
                Text(.localizable(.inspectorGenerateIconFromApp)).tag(AssetMode.automatic)
                Text(.localizable(.inspectorCustomImage)).tag(AssetMode.custom)
                Text(.localizable(.generalNone)).tag(AssetMode.none)
            }
            if model.options.diskIcon == .custom {
                InspectorAssetRow(url: model.options.diskIconURL) { model.chooseImage(forBackground: false) }
            }
            VStack(spacing: 6) {
                if let previewError {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .frame(width: 72, height: 72)
                    Text(.localizable(.inspectorIconPreviewUnavailable))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .help(previewError)
                } else {
                    Image(nsImage: preview ?? NSWorkspace.shared.icon(for: .diskImage))
                        .resizable()
                        .scaledToFit()
                        .frame(width: 72, height: 72)
                        .accessibilityLabel(.localizable(.inspectorDiskIconPreview))
                        .help(String(localizable: .inspectorDiskIconPreview))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .task(id: request) {
            let requested = request
            // Yield so the inspector can appear before generating the icon representations.
            await Task.yield()
            guard !Task.isCancelled else { return }
            previewError = nil
            do {
                let option: AppDMG.DMGIconOption
                switch requested.mode {
                case .automatic:
                    option = .default
                case .custom:
                    guard let url = requested.customURL else {
                        preview = nil
                        return
                    }
                    option = .manually(url)
                case .none:
                    option = .skip
                }
                if let sourceURL = requested.sourceURL {
                    preview = try AppDMG.default.diskIcon(forAppAt: sourceURL, option: option)
                } else {
                    preview = nil
                }
            } catch {
                preview = nil
                previewError = error.localizedDescription
            }
        }
    }
}

#if !SWIFTYDMG_SIDEBAR && SWIFTYDMG_ADDITIONAL_FILES
private struct AdditionalFilesSettingsSection: View {
    @Bindable var model: PackagingModel

    var body: some View {
        Section(.localizable(.inspectorAdditionalFilesSection)) {
            ForEach($model.options.extraItems) { $item in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        TextField(.localizable(.generalFileName), text: $item.name)
                            .labelsHidden().textFieldStyle(.roundedBorder)
                        Menu {
                            Button(.localizable(.sidebarReplaceFile)) { model.replaceFile(item.id) }
                            Button(.localizable(.generalShowInFinder)) { NSWorkspace.shared.activateFileViewerSelecting([item.url]) }
                            Divider()
                            Button(.localizable(.generalButtonRemove), role: .destructive) {
                                model.options.extraItems.removeAll { $0.id == item.id }
                            }
                        } label: { Label(.localizable(.inspectorFileActions), systemImage: "ellipsis") }
                        .labelStyle(.iconOnly)
                        .menuIndicator(.hidden)
                        .help(String(localizable: .inspectorFileActions))
                    }
                    LabeledContent(.localizable(.generalPosition)) {
                        CoordinateFields(first: $item.x, second: $item.y,
                                         firstRange: 0...model.options.windowWidth, secondRange: 0...model.options.windowHeight)
                    }
                    .labeledContentStyle(InspectorInlineRowStyle())
                    if !FileManager.default.fileExists(atPath: item.url.path) {
                        Label(.localizable(.inspectorMissingFileMessage), systemImage: "exclamationmark.triangle")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }
                .padding(.vertical, 8)
            }
            Button(action: model.addFiles) { Label(.localizable(.inspectorAddFiles), systemImage: "plus") }
        }
        .controlSize(.regular)
    }
}
#endif

private struct OutputSettingsSection: View {
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

private struct InspectorResetButton: View {
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

private struct InspectorResetLabel: View {
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

private struct InspectorInlineRowStyle: LabeledContentStyle {
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

private struct PositionSettingsRow: View {
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

private struct InspectorAssetRow: View {
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
