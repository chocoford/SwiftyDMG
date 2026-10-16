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
                Section("Appearance") {
                    Picker("Background", selection: $model.options.background) {
                        Text("Default Background").tag(AssetMode.automatic)
                        Text("Custom Image").tag(AssetMode.custom)
                        Text("No Background").tag(AssetMode.none)
                    }
                    if model.options.background == .custom {
                        InspectorAssetRow(url: model.options.backgroundURL) { model.chooseImage(forBackground: true) }
                    }
                    DiskIconSettingsRow(model: model)
                }
                Section("Finder Window") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Volume Name").fontWeight(.medium)
                        TextField("Volume Name", text: Binding(
                            get: { model.options.volumeName ?? "" },
                            set: { model.options.volumeName = $0.isEmpty ? nil : $0 }
                        ), prompt: Text(PackagingOptions.defaultVolumeName(for: model.sourceURL)))
                        .labelsHidden()
                        .textFieldStyle(.roundedBorder)
                        .help("The name shown when the disk image is mounted. Leave blank to use the app name.")
                        .accessibilityIdentifier("volumeNameField")
                    }
                    .controlSize(.regular)
                    .padding(.bottom, 8)
                    LabeledContent("Size") {
                        CoordinateFields(
                            first: $model.options.windowWidth, second: $model.options.windowHeight,
                            firstLabel: "W", secondLabel: "H",
                            firstRange: 320...4096, secondRange: 240...4096,
                            firstDefault: PackagingOptions().windowWidth, secondDefault: PackagingOptions().windowHeight
                        )
                    }
                    .labeledContentStyle(InspectorInlineRowStyle())
                    #if SWIFTYDMG_SIDEBAR
                    selectedItemPosition
                    #else
                    PositionSettingsRow(
                        title: "App Position", x: $model.options.appX, y: $model.options.appY,
                        resetTitle: "Reset App Position", resetIdentifier: "resetAppPositionButton",
                        reset: model.resetAppPosition,
                        maxX: model.options.windowWidth, maxY: model.options.windowHeight
                    )
                    Toggle("Applications Link", isOn: $model.options.includeApplications)
                    if model.options.includeApplications {
                        PositionSettingsRow(
                            title: "Link Position", x: $model.options.applicationsX, y: $model.options.applicationsY,
                            resetTitle: "Reset Link Position", resetIdentifier: "resetLinkPositionButton",
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
                Section("DMG Signing") {
                    Picker("Signing", selection: $model.options.signing) {
                        Text("None").tag(SigningMode.none)
                        Text("Automatically Select Certificate").tag(SigningMode.automatic)
                        Text("Specific Identity").tag(SigningMode.identity)
                    }
                    if model.options.signing == .identity {
                        TextField("Identity name or SHA-1", text: $model.options.signingIdentity)
                    }
                    Text("Only the generated DMG is signed.").font(.caption).foregroundStyle(.secondary)
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
                title: "Position", x: $model.options.appX, y: $model.options.appY,
                resetTitle: "Reset App Position", resetIdentifier: "resetAppPositionButton",
                reset: model.resetAppPosition,
                maxX: model.options.windowWidth, maxY: model.options.windowHeight
            )
        case .applications:
            if model.options.includeApplications {
                PositionSettingsRow(
                    title: "Position", x: $model.options.applicationsX, y: $model.options.applicationsY,
                    resetTitle: "Reset Link Position", resetIdentifier: "resetLinkPositionButton",
                    reset: model.resetApplicationsPosition,
                    maxX: model.options.windowWidth, maxY: model.options.windowHeight,
                    defaultX: PackagingOptions().applicationsX, defaultY: PackagingOptions().applicationsY
                )
            }
        case .extra(let id):
            ForEach($model.options.extraItems) { $item in
                if item.id == id {
                    LabeledContent("Position") {
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
            Picker("Disk Icon", selection: $model.options.diskIcon) {
                Text("Generate from App").tag(AssetMode.automatic)
                Text("Custom Image").tag(AssetMode.custom)
                Text("None").tag(AssetMode.none)
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
                    Text("Unable to Preview Icon")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .help(previewError)
                } else {
                    Image(nsImage: preview ?? NSWorkspace.shared.icon(for: .diskImage))
                        .resizable()
                        .scaledToFit()
                        .frame(width: 72, height: 72)
                        .accessibilityLabel("Disk Icon Preview")
                        .help("Disk Icon Preview")
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
        Section("Additional Files") {
            ForEach($model.options.extraItems) { $item in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        TextField("File Name", text: $item.name)
                            .labelsHidden().textFieldStyle(.roundedBorder)
                        Menu {
                            Button("Replace File…") { model.replaceFile(item.id) }
                            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([item.url]) }
                            Divider()
                            Button("Remove", role: .destructive) {
                                model.options.extraItems.removeAll { $0.id == item.id }
                            }
                        } label: { Label("File Actions", systemImage: "ellipsis") }
                        .labelStyle(.iconOnly)
                        .menuIndicator(.hidden)
                        .help("File Actions")
                    }
                    LabeledContent("Position") {
                        CoordinateFields(first: $item.x, second: $item.y,
                                         firstRange: 0...model.options.windowWidth, secondRange: 0...model.options.windowHeight)
                    }
                    .labeledContentStyle(InspectorInlineRowStyle())
                    if !FileManager.default.fileExists(atPath: item.url.path) {
                        Label("File not found. Use Replace File to locate it.", systemImage: "exclamationmark.triangle")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }
                .padding(.vertical, 8)
            }
            Button(action: model.addFiles) { Label("Add Files…", systemImage: "plus") }
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
        directoryURL?.path ?? String(localized: "No Folder Selected")
    }

    var body: some View {
        Section("Output") {
            LabeledContent {
                HStack(spacing: 8) {
                    TextField("File Name", text: $model.outputName)
                        .labelsHidden()
                        .textFieldStyle(.roundedBorder)
                        .help("The .dmg extension is added automatically.")
                        .accessibilityIdentifier("outputNameField")
                    Text(".dmg").foregroundStyle(.secondary)
                }
            } label: {
                InspectorResetLabel(title: "File Name", resetTitle: "Reset File Name",
                                    resetIdentifier: "resetOutputNameButton", reset: model.resetOutputName,
                                    canReset: model.sourceURL != nil)
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Save Location").fontWeight(.medium)
                    Spacer(minLength: 12)
                    Button("Change…", action: model.chooseOutput)
                }
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "folder")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    Text(directoryPath)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                        .help(directoryPath)
                    Button("Open Save Location in Finder", systemImage: "arrow.right.circle.fill") {
                        guard let directoryURL else { return }
                        NSWorkspace.shared.open(directoryURL)
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .font(.callout)
                    .controlSize(.regular)
                    .imageScale(.medium)
                    .help("Open Save Location in Finder")
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
            Text(url?.lastPathComponent ?? String(localized: "Not Selected")).font(.caption).lineLimit(1).truncationMode(.middle)
            Spacer()
            Button("Choose…", action: action)
        }
    }
}

struct CoordinateFields: View {
    @Binding var first: Double
    @Binding var second: Double
    var firstLabel: LocalizedStringResource = "X"
    var secondLabel: LocalizedStringResource = "Y"
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
