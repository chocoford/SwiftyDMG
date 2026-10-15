import AppKit
import SwiftUI

struct PackagingSettingsView: View {
    @Bindable var model: PackagingModel

    var body: some View {
        Form {
            Section {
                if let source = model.sourceURL {
                    HStack(spacing: 10) {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: source.path)).resizable().frame(width: 32, height: 32)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(source.lastPathComponent).fontWeight(.medium).lineLimit(1)
                            Text(source.deletingLastPathComponent().path).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                        }
                    }.help(source.path)
                }
            }
            Section("输出") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(model.outputURL?.lastPathComponent ?? "未选择输出文件").lineLimit(2).textSelection(.enabled)
                    HStack(alignment: .top) {
                        Text(model.outputURL?.deletingLastPathComponent().path ?? "")
                            .font(.caption).foregroundStyle(.secondary).lineLimit(2).truncationMode(.middle)
                        Spacer(minLength: 4)
                        Button("更改…", action: model.chooseOutput)
                    }
                }
            }
            Section("外观") {
                Picker("背景", selection: $model.options.background) {
                    Text("默认背景").tag(AssetMode.automatic)
                    Text("自定义图片").tag(AssetMode.custom)
                    Text("无背景").tag(AssetMode.none)
                }
                if model.options.background == .custom {
                    InspectorAssetRow(url: model.options.backgroundURL) { model.chooseImage(forBackground: true) }
                }
                Picker("磁盘图标", selection: $model.options.diskIcon) {
                    Text("根据 App 生成").tag(AssetMode.automatic)
                    Text("自定义图片").tag(AssetMode.custom)
                    Text("不设置").tag(AssetMode.none)
                }
                if model.options.diskIcon == .custom {
                    InspectorAssetRow(url: model.options.diskIconURL) { model.chooseImage(forBackground: false) }
                }
            }
            Section("Finder 窗口") {
                LabeledContent("尺寸") {
                    CoordinateFields(first: $model.options.windowWidth, second: $model.options.windowHeight, firstLabel: "W", secondLabel: "H")
                }
                LabeledContent("App") { CoordinateFields(first: $model.options.appX, second: $model.options.appY) }
                Toggle("Applications 链接", isOn: $model.options.includeApplications)
                if model.options.includeApplications {
                    LabeledContent("链接") { CoordinateFields(first: $model.options.applicationsX, second: $model.options.applicationsY) }
                }
            }
            Section("附加文件") {
                ForEach($model.options.extraItems) { $item in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            TextField("文件名", text: $item.name)
                            Button {
                                model.options.extraItems.removeAll { $0.id == item.id }
                            } label: { Image(systemName: "minus.circle") }
                            .buttonStyle(.borderless).help("移除 \(item.name)")
                        }
                        CoordinateFields(first: $item.x, second: $item.y)
                    }
                }
                Button(action: model.addFiles) { Label("添加文件…", systemImage: "plus") }
            }
            Section("DMG 签名") {
                Picker("签名", selection: $model.options.signing) {
                    Text("不签名").tag(SigningMode.none)
                    Text("自动选择证书").tag(SigningMode.automatic)
                    Text("指定身份").tag(SigningMode.identity)
                }
                if model.options.signing == .identity {
                    TextField("身份名称或 SHA-1", text: $model.options.signingIdentity)
                }
                Text("仅签名生成的 DMG。").font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .controlSize(.small)
        .disabled(model.isBuilding)
    }
}

private struct InspectorAssetRow: View {
    let url: URL?
    let action: () -> Void

    var body: some View {
        HStack {
            Text(url?.lastPathComponent ?? "尚未选择").font(.caption).lineLimit(1).truncationMode(.middle)
            Spacer()
            Button("选择…", action: action)
        }
    }
}

struct CoordinateFields: View {
    @Binding var first: Double
    @Binding var second: Double
    var firstLabel = "X"
    var secondLabel = "Y"

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
