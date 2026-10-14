import AppKit
import SwiftUI

struct ContentView: View {
    @Bindable var model: PackagingModel
    let delegate: ApplicationDelegate
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "externaldrive.fill.badge.plus").font(.title).foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 4) {
                    Text("SwiftyDMG").font(.title2.bold())
                    Text("为你的 App 制作一个漂亮的安装镜像").foregroundStyle(.secondary)
                }
                Spacer()
                Button("选择 App…", action: model.chooseApp).disabled(model.isBuilding)
            }.padding(24)
            Divider()
            HSplitView {
                ScrollView {
                    PackagingSettingsView(model: model)
                        .padding(20)
                }.frame(minWidth: 330, idealWidth: 355, maxWidth: 430)
                VStack(alignment: .leading, spacing: 20) {
                    appSelection
                    HStack {
                        Label("布局预览", systemImage: "rectangle.inset.filled").font(.headline)
                        Spacer()
                        Text("拖动图标调整位置").font(.caption).foregroundStyle(.secondary)
                    }
                    LayoutPreview(options: $model.options, sourceURL: model.sourceURL)
                        .disabled(model.isBuilding)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    outputSelection
                }.padding(24).frame(minWidth: 540)
            }
            Divider()
            footer.padding(20)
        }
        .onAppear { delegate.showMainWindow = { openWindow(id: "main") } }
        .onOpenURL(perform: model.selectApp)
        .alert("无法完成操作", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("复制错误") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(model.errorMessage ?? "", forType: .string) }
            Button("好", role: .cancel) {}
        } message: { Text(model.errorMessage ?? "") }
        .confirmationDialog("替换已有 DMG？", isPresented: $model.confirmReplacement, titleVisibility: .visible) {
            Button("替换", role: .destructive) { model.startBuild(replaceExisting: true) }
            Button("取消", role: .cancel) {}
        } message: { Text("打包成功后才会替换 \(model.outputURL?.lastPathComponent ?? "DMG")。") }
    }

    private var appSelection: some View {
        HStack(spacing: 16) {
            if let url = model.sourceURL {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().frame(width: 52, height: 52)
                VStack(alignment: .leading, spacing: 5) {
                    Text(url.lastPathComponent).font(.headline)
                    Text(url.deletingLastPathComponent().path).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                }
            } else {
                Image(systemName: "app.badge").font(.system(size: 38)).foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 5) {
                    Text("拖入一个 .app").font(.headline)
                    Text("也可以从 Finder 服务或「选择 App」打开").font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.secondary.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: model.sourceURL == nil ? [5, 4] : [])))
        .dropDestination(for: URL.self) { urls, _ in
            guard urls.count == 1, !model.isBuilding else { return false }
            model.selectApp(urls[0])
            return urls[0].pathExtension.lowercased() == "app"
        }
        .accessibilityIdentifier("appDropArea")
    }

    private var outputSelection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text("输出文件").font(.caption).foregroundStyle(.secondary)
                Text(model.outputURL?.path ?? "选择 App 后生成默认文件名")
                    .font(.callout).lineLimit(1).truncationMode(.middle).textSelection(.enabled)
            }
            Spacer()
            Button("更改…", action: model.chooseOutput).disabled(model.sourceURL == nil || model.isBuilding)
        }
    }

    private var footer: some View {
        HStack(alignment: .center, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    if model.resultURL != nil { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
                    Text(model.status).font(.callout)
                }
                if model.isBuilding { ProgressView(value: model.progress).frame(width: 250) }
                if !model.log.isEmpty {
                    DisclosureGroup("查看打包日志") {
                        ScrollView {
                            Text(model.log.joined(separator: "\n")).font(.caption.monospaced()).textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }.frame(maxHeight: 100)
                    }.font(.caption).frame(maxWidth: 550)
                }
            }
            Spacer()
            if let url = model.resultURL {
                Button("在 Finder 中显示") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
            }
            Button(action: { model.startBuild() }) {
                Label(model.isBuilding ? "正在打包…" : "创建 DMG", systemImage: "shippingbox")
                    .padding(.horizontal, 12).padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(model.sourceURL == nil || model.isBuilding)
            .accessibilityIdentifier("createDMGButton")
        }
    }
}

struct PackagingSettingsView: View {
    @Bindable var model: PackagingModel

    var body: some View {
        Form {
            Section("外观") {
                Picker("背景", selection: $model.options.background) {
                    Text("默认背景").tag(AssetMode.automatic)
                    Text("自定义图片").tag(AssetMode.custom)
                    Text("无背景").tag(AssetMode.none)
                }
                if model.options.background == .custom {
                    assetRow(model.options.backgroundURL) { model.chooseImage(forBackground: true) }
                }
                Picker("磁盘图标", selection: $model.options.diskIcon) {
                    Text("根据 App 生成").tag(AssetMode.automatic)
                    Text("自定义图片").tag(AssetMode.custom)
                    Text("不设置").tag(AssetMode.none)
                }
                if model.options.diskIcon == .custom {
                    assetRow(model.options.diskIconURL) { model.chooseImage(forBackground: false) }
                }
            }
            Section("Finder 窗口") {
                CoordinateFields(first: $model.options.windowWidth, second: $model.options.windowHeight, firstLabel: "宽", secondLabel: "高")
                LabeledContent("App 位置") {
                    CoordinateFields(first: $model.options.appX, second: $model.options.appY)
                }
                Toggle("添加 Applications 链接", isOn: $model.options.includeApplications)
                if model.options.includeApplications {
                    LabeledContent("链接位置") {
                        CoordinateFields(first: $model.options.applicationsX, second: $model.options.applicationsY)
                    }
                }
            }
            Section("附加文件") {
                ForEach($model.options.extraItems) { $item in
                    VStack(alignment: .leading, spacing: 6) {
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
                Button("添加文件…", action: model.addFiles)
            }
            Section("DMG 签名") {
                Picker("签名方式", selection: $model.options.signing) {
                    Text("不签名").tag(SigningMode.none)
                    Text("自动选择证书").tag(SigningMode.automatic)
                    Text("指定身份").tag(SigningMode.identity)
                }
                if model.options.signing == .identity {
                    TextField("身份名称或 SHA-1", text: $model.options.signingIdentity)
                }
                Text("签名作用于生成的 DMG，App 本身的签名不会改变。")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .disabled(model.isBuilding)
    }

    private func assetRow(_ url: URL?, action: @escaping () -> Void) -> some View {
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
        HStack(spacing: 8) {
            Text(firstLabel).foregroundStyle(.secondary)
            TextField(firstLabel, value: $first, format: .number.precision(.fractionLength(0)))
                .frame(width: 58).textFieldStyle(.roundedBorder).accessibilityLabel(firstLabel)
            Text(secondLabel).foregroundStyle(.secondary)
            TextField(secondLabel, value: $second, format: .number.precision(.fractionLength(0)))
                .frame(width: 58).textFieldStyle(.roundedBorder).accessibilityLabel(secondLabel)
        }.font(.caption)
    }
}

#Preview("选择 App") {
    let delegate = ApplicationDelegate()
    ContentView(model: PackagingModel(defaults: UserDefaults(suiteName: "SwiftyDMG.preview")!), delegate: delegate)
        .frame(width: 1080, height: 760)
}
