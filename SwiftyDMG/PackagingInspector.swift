import AppKit
import SwiftUI

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
                    Picker("Disk Icon", selection: $model.options.diskIcon) {
                        Text("Generate from App").tag(AssetMode.automatic)
                        Text("Custom Image").tag(AssetMode.custom)
                        Text("None").tag(AssetMode.none)
                    }
                    if model.options.diskIcon == .custom {
                        InspectorAssetRow(url: model.options.diskIconURL) { model.chooseImage(forBackground: false) }
                    }
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
                    .padding(.vertical, 8)
                    LabeledContent("Size") {
                        CoordinateFields(first: $model.options.windowWidth, second: $model.options.windowHeight, firstLabel: "W", secondLabel: "H")
                    }
                    #if SWIFTYDMG_SIDEBAR
                    selectedItemPosition
                    #else
                    PositionSettingsRow(
                        title: "App Position", x: $model.options.appX, y: $model.options.appY,
                        resetTitle: "Reset App Position", resetIdentifier: "resetAppPositionButton",
                        reset: model.resetAppPosition
                    )
                    Toggle("Applications Link", isOn: $model.options.includeApplications)
                    if model.options.includeApplications {
                        PositionSettingsRow(
                            title: "Link Position", x: $model.options.applicationsX, y: $model.options.applicationsY,
                            resetTitle: "Reset Link Position", resetIdentifier: "resetLinkPositionButton",
                            reset: model.resetApplicationsPosition
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
                reset: model.resetAppPosition
            )
        case .applications:
            if model.options.includeApplications {
                PositionSettingsRow(
                    title: "Position", x: $model.options.applicationsX, y: $model.options.applicationsY,
                    resetTitle: "Reset Link Position", resetIdentifier: "resetLinkPositionButton",
                    reset: model.resetApplicationsPosition
                )
            }
        case .extra(let id):
            ForEach($model.options.extraItems) { $item in
                if item.id == id {
                    LabeledContent("Position") { CoordinateFields(first: $item.x, second: $item.y) }
                }
            }
        case nil:
            EmptyView()
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
                    LabeledContent("Position") { CoordinateFields(first: $item.x, second: $item.y) }
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
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("File Name").fontWeight(.medium)
                    Spacer(minLength: 12)
                    InspectorResetButton(title: "Reset File Name", action: model.resetOutputName)
                        .help("Reset to the app name and version")
                        .disabled(model.sourceURL == nil)
                        .accessibilityIdentifier("resetOutputNameButton")
                }
                HStack(spacing: 8) {
                    TextField("File Name", text: $model.outputName)
                        .labelsHidden()
                        .textFieldStyle(.roundedBorder)
                        .help("The .dmg extension is added automatically.")
                        .accessibilityIdentifier("outputNameField")
                    Text(".dmg").foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 8)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Save Location").fontWeight(.medium)
                    Spacer(minLength: 12)
                    Button("Change…", action: model.chooseOutput)
                }
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "folder")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    Text(directoryPath)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .help(directoryPath)
                    Button("Open Save Location in Finder", systemImage: "arrow.right.circle.fill") {
                        guard let directoryURL else { return }
                        NSWorkspace.shared.open(directoryURL)
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    .imageScale(.small)
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

private struct PositionSettingsRow: View {
    let title: LocalizedStringKey
    @Binding var x: Double
    @Binding var y: Double
    let resetTitle: LocalizedStringKey
    let resetIdentifier: String
    let reset: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title).fontWeight(.medium)
                Spacer(minLength: 12)
                InspectorResetButton(title: resetTitle, action: reset)
                    .help(resetTitle)
                    .accessibilityIdentifier(resetIdentifier)
            }
            CoordinateFields(first: $x, second: $y)
        }
        .padding(.vertical, 8)
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
    var firstLabel: LocalizedStringKey = "X"
    var secondLabel: LocalizedStringKey = "Y"

    var body: some View {
        HStack(spacing: 5) {
            Text(firstLabel).foregroundStyle(.secondary)
            TextField(firstLabel, value: $first, format: .number.precision(.fractionLength(0)))
                .labelsHidden().frame(width: 48).accessibilityLabel(firstLabel)
            Text(secondLabel).foregroundStyle(.secondary)
            TextField(secondLabel, value: $second, format: .number.precision(.fractionLength(0)))
                .labelsHidden().frame(width: 48).accessibilityLabel(secondLabel)
        }
        .textFieldStyle(.roundedBorder)
        .multilineTextAlignment(.trailing)
        .font(.caption)
    }
}
