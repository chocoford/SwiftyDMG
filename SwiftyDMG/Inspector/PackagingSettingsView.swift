import SwiftUI

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
