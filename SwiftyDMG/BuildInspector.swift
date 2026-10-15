import AppKit
import SwiftUI

struct BuildInspector: View {
    let model: PackagingModel

    private var hasActivity: Bool { model.isBuilding || !model.log.isEmpty }
    private var statusColor: Color { model.resultURL != nil ? .green : hasActivity ? .orange : .secondary }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    if model.isBuilding {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: model.resultURL != nil ? "checkmark.circle.fill" : hasActivity ? "exclamationmark.circle.fill" : "hammer")
                            .foregroundStyle(statusColor)
                    }
                    Text(model.status).font(.headline)
                    Spacer()
                    if hasActivity { Text(model.progress, format: .percent.precision(.fractionLength(0))).font(.caption).foregroundStyle(.secondary).monospacedDigit() }
                }
                if hasActivity { ProgressView(value: model.progress).tint(model.resultURL != nil ? .green : .accentColor) }
                if let result = model.resultURL {
                    Text(result.lastPathComponent).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                    Button("在 Finder 中显示") { NSWorkspace.shared.activateFileViewerSelecting([result]) }
                } else if !hasActivity {
                    Text("点击右上角的播放按钮创建 DMG。\n打包进度和日志会显示在这里。")
                        .font(.callout).foregroundStyle(.secondary).lineSpacing(4)
                }
            }.padding(16)
            Divider()
            HStack {
                Text("日志").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                Button(action: copyLog) { Image(systemName: "doc.on.doc") }
                    .buttonStyle(.borderless).help("复制打包日志").disabled(model.log.isEmpty)
            }.padding(.horizontal, 16).padding(.vertical, 10)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        if model.log.isEmpty {
                            Text("暂无日志").foregroundStyle(.tertiary)
                        } else {
                            Text(model.log.joined(separator: "\n\n")).textSelection(.enabled)
                        }
                        Color.clear.frame(height: 1).id("logEnd")
                    }
                    .font(.system(size: 11, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16).padding(.bottom, 16)
                }
                .onChange(of: model.log.count) { _, _ in proxy.scrollTo("logEnd", anchor: .bottom) }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityIdentifier("buildInspector")
    }

    private func copyLog() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(model.log.joined(separator: "\n"), forType: .string)
    }
}
