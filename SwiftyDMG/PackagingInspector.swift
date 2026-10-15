import AppKit
import SwiftUI

struct PackagingSettingsView: View {
    @Bindable var model: PackagingModel
    var selection: WorkspaceItem? = nil

    var body: some View {
        ScrollViewReader { proxy in
            Form {
                Section {
                    if let source = model.sourceURL {
                        HStack(spacing: 10) {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: source.path)).resizable().frame(width: 32, height: 32)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(source.lastPathComponent).fontWeight(.medium).lineLimit(1)
                                Text(source.deletingLastPathComponent().path).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                            Button("Change…", action: model.chooseApp)
                                .help("Change the app while keeping the current layout and assets")
                        }.help(source.path)
                        if !FileManager.default.fileExists(atPath: source.path) {
                            Label("App not found. Choose it again.", systemImage: "exclamationmark.triangle")
                                .font(.caption).foregroundStyle(.orange)
                        }
                    }
                }.id("app")
                Section("Output") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(model.outputURL?.lastPathComponent ?? String(localized: "No Output Selected")).lineLimit(2).textSelection(.enabled)
                        HStack(alignment: .top) {
                            Text(model.outputURL?.deletingLastPathComponent().path ?? "")
                                .font(.caption).foregroundStyle(.secondary).lineLimit(2).truncationMode(.middle)
                            Spacer(minLength: 4)
                            Button("Change…", action: model.chooseOutput)
                        }
                    }
                    Toggle("Use App Name and Version", isOn: $model.usesAutomaticOutputName)
                }
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
                }.id("appearance")
                Section("Finder Window") {
                    LabeledContent("Size") {
                        CoordinateFields(first: $model.options.windowWidth, second: $model.options.windowHeight, firstLabel: "W", secondLabel: "H")
                    }
                    LabeledContent("App") { CoordinateFields(first: $model.options.appX, second: $model.options.appY) }
                    Toggle("Applications Link", isOn: $model.options.includeApplications)
                    if model.options.includeApplications {
                        LabeledContent("Link") { CoordinateFields(first: $model.options.applicationsX, second: $model.options.applicationsY) }
                    }
                }.id("layout")
                Section("Additional Files") {
                    ForEach($model.options.extraItems) { $item in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                TextField("File Name", text: $item.name)
                                Button {
                                    model.options.extraItems.removeAll { $0.id == item.id }
                                } label: { Image(systemName: "minus.circle") }
                                .buttonStyle(.borderless).help("Remove \(item.name)")
                            }
                            CoordinateFields(first: $item.x, second: $item.y)
                        }.id("extra-\(item.id.uuidString)")
                    }
                    Button(action: model.addFiles) { Label("Add Files…", systemImage: "plus") }
                }
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
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .controlSize(.small)
            .disabled(model.isBuilding)
            .onChange(of: selection, initial: true) { _, selected in
                if let selected { proxy.scrollTo(selected.inspectorAnchor, anchor: .top) }
            }
        }
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
