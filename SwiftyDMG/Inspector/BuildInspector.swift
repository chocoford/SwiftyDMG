import AppKit
import SwiftUI

struct BuildInspector: View {
    let model: PackagingModel
    @State private var expansionOverrides: [UUID: Bool] = [:]

    private var hasActivity: Bool { model.isBuilding || !model.logSteps.isEmpty }
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
                    Text(verbatim: model.status).font(.headline)
                    Spacer()
                    if hasActivity { Text(model.progress, format: .percent.precision(.fractionLength(0))).font(.caption).foregroundStyle(.secondary).monospacedDigit() }
                }
                if hasActivity { ProgressView(value: model.progress).tint(model.resultURL != nil ? .green : .accentColor) }
                if let result = model.resultURL {
                    Text(verbatim: result.lastPathComponent).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                    Button(.localizable(.generalShowInFinder)) { NSWorkspace.shared.activateFileViewerSelecting([result]) }
                } else if !hasActivity {
                    Text(.localizable(.buildStartHelp))
                        .font(.callout).foregroundStyle(.secondary).lineSpacing(4)
                }
            }.padding(16)
            Divider()
            HStack {
                Text(.localizable(.buildLogsTitle)).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                Button(action: copyLog) { Image(systemName: "doc.on.doc") }
                    .buttonStyle(.borderless).help(String(localizable: .buildCopyEntireLog)).disabled(model.logSteps.isEmpty)
                    .accessibilityLabel(.localizable(.buildCopyEntireLog))
            }.padding(.horizontal, 16).padding(.vertical, 10)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        if model.logSteps.isEmpty {
                            Text(.localizable(.buildLogsEmpty)).foregroundStyle(.tertiary)
                        } else {
                            ForEach(model.logSteps) { step in
                                BuildLogStepView(step: step, isExpanded: Binding(
                                    get: { isExpanded(step) },
                                    set: { expansionOverrides[step.id] = $0 }
                                ))
                                .id(step.id)
                            }
                        }
                        Color.clear.frame(height: 1).id("logEnd")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12).padding(.bottom, 16)
                }
                .onChange(of: model.logSteps.first?.id) { _, _ in expansionOverrides.removeAll() }
                .onChange(of: model.logSteps.last?.id) { _, _ in
                    if followsCurrentStep { proxy.scrollTo("logEnd", anchor: .bottom) }
                }
                .onChange(of: model.logSteps.last?.entries.last?.id) { _, _ in
                    if followsCurrentStep { proxy.scrollTo("logEnd", anchor: .bottom) }
                }
                .onChange(of: model.isBuilding) { _, building in
                    guard !building, let failed = model.logSteps.last, failed.status == .failed else { return }
                    expansionOverrides[failed.id] = true
                    proxy.scrollTo(failed.id, anchor: .top)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityIdentifier("buildInspector")
    }

    private func isExpanded(_ step: BuildLogStep) -> Bool {
        expansionOverrides[step.id] ?? (step.status != .succeeded)
    }

    private var followsCurrentStep: Bool {
        guard let current = model.logSteps.last, isExpanded(current) else { return false }
        // Let people inspect earlier output without new lines pulling them away.
        return !model.logSteps.dropLast().contains(where: isExpanded)
    }

    private func copyLog() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(model.buildLogText, forType: .string)
    }
}

private struct BuildLogStepView: View {
    let step: BuildLogStep
    @Binding var isExpanded: Bool

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                Divider()
                Text(verbatim: step.entries.map(\.text).joined(separator: "\n"))
                    .font(.system(size: 11, design: .monospaced))
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            .padding(.top, 6)
        } label: {
            HStack(spacing: 8) {
                statusIcon
                    .frame(width: 12, height: 12)
                Text(verbatim: step.heading.message)
                    .font(.callout.weight(.medium))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                duration
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .fixedSize()
            }
            .padding(.vertical, 2)
        }
        .padding(10)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
        .contextMenu {
            Button(.localizable(.buildCopyStepLog), systemImage: "doc.on.doc") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(step.text, forType: .string)
            }
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch step.status {
        case .running:
            ProgressView()
                .controlSize(.mini)
                .accessibilityLabel(.localizable(.buildStepRunning))
        case .succeeded:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .accessibilityLabel(.localizable(.buildStepSucceeded))
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
                .accessibilityLabel(.localizable(.buildStepFailed))
        }
    }

    @ViewBuilder
    private var duration: some View {
        if let finishedAt = step.finishedAt {
            elapsedText(at: finishedAt)
        } else {
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                elapsedText(at: ProcessInfo.processInfo.systemUptime)
            }
        }
    }

    private func elapsedText(at uptime: TimeInterval) -> Text {
        Text(.localizable(.buildStepDuration(step.duration(at: uptime))))
    }
}
