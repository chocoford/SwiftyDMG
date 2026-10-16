import AppKit
import SwiftUI

#if !SWIFTYDMG_SIDEBAR && SWIFTYDMG_ADDITIONAL_FILES
struct AdditionalFilesSettingsSection: View {
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
