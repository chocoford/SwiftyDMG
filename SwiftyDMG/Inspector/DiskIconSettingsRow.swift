import AppKit
import AppDMG
import SwiftUI
import UniformTypeIdentifiers

struct DiskIconSettingsRow: View {
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
