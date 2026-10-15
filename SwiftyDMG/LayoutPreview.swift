import AppKit
import DSStoreKit
import SwiftUI

enum PreviewZoom: String, CaseIterable, Identifiable {
    case fit, half, actual, double
    var id: Self { self }
    var title: String {
        switch self {
        case .fit: String(localized: "Fit to Window")
        case .half: "50%"
        case .actual: "100%"
        case .double: "200%"
        }
    }
    var scale: Double? {
        switch self {
        case .fit: nil
        case .half: 0.5
        case .actual: 1
        case .double: 2
        }
    }
}

enum PreviewAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var symbol: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max"
        case .dark: "moon"
        }
    }

    func colorScheme(following system: ColorScheme) -> ColorScheme {
        switch self {
        case .system: system
        case .light: .light
        case .dark: .dark
        }
    }
}

struct PreviewCanvas: View {
    @Environment(\.colorScheme) private var systemColorScheme
    @Binding var options: PackagingOptions
    let sourceURL: URL?
    let isBuilding: Bool
    @State private var zoom = PreviewZoom.fit
    @State private var appearance = PreviewAppearance.system

    var body: some View {
        VStack(spacing: 0) {
            LayoutPreview(options: $options, sourceURL: sourceURL, zoom: zoom)
                .environment(\.colorScheme, appearance.colorScheme(following: systemColorScheme))
                .disabled(isBuilding)
            HStack(spacing: 12) {
                Picker("Preview Zoom", selection: $zoom) {
                    ForEach(PreviewZoom.allCases) { Text($0.title).tag($0) }
                }
                .labelsHidden().frame(width: 110)
                Menu {
                    Picker("Preview Appearance", selection: $appearance) {
                        ForEach(PreviewAppearance.allCases) { mode in
                            Label(mode.title, systemImage: mode.symbol).tag(mode)
                        }
                    }
                } label: {
                    Label("Preview Appearance", systemImage: appearance.symbol)
                }
                .labelStyle(.iconOnly)
                .help("Choose the preview appearance. Background images retain their original colors.")
                .accessibilityIdentifier("previewAppearanceMenu")
                Spacer()
                Text("Drag icons to adjust the layout").foregroundStyle(.secondary)
                    .lineLimit(1).layoutPriority(-1)
                Spacer()
                Text("\(options.windowWidth, format: .number.precision(.fractionLength(0))) × \(options.windowHeight, format: .number.precision(.fractionLength(0)))")
                    .monospacedDigit().foregroundStyle(.secondary).lineLimit(1)
            }
            .font(.caption).controlSize(.small).padding(14)
        }
        .background(Color(nsColor: .underPageBackgroundColor))
    }
}

struct LayoutPreview: View {
    @Binding var options: PackagingOptions
    var sourceURL: URL?
    var zoom = PreviewZoom.fit

    private var width: Double { options.windowWidth.isFinite ? min(4096, max(320, options.windowWidth)) : 660 }
    private var height: Double { options.windowHeight.isFinite ? min(4096, max(240, options.windowHeight)) : 400 }
    // bwsp.WindowBounds describes the entire Finder window, including its title bar.
    private var titleHeight: Double {
        let content = NSWindow.contentRect(forFrameRect: NSRect(x: 0, y: 0, width: width, height: height), styleMask: [.titled, .closable, .miniaturizable, .resizable])
        return height - content.height
    }
    private var contentHeight: Double { height - titleHeight }
    private var backgroundImage: NSImage? {
        switch options.background {
        case .none: nil
        case .custom: options.backgroundURL.flatMap { NSImage(contentsOf: $0) }
        case .automatic: Bundle.main.url(forResource: "dmg-background", withExtension: "tiff").flatMap { NSImage(contentsOf: $0) }
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let fit = max(0.05, min(1, (geometry.size.width - 64) / width, (geometry.size.height - 64) / height))
            let scale = zoom.scale ?? fit
            let image = backgroundImage
            let labelColor: Color = image == nil ? .primary : .black
            ScrollView([.horizontal, .vertical]) {
                FinderWindowPreview(title: options.resolvedVolumeName(for: sourceURL), titleHeight: titleHeight) {
                    ZStack(alignment: .topLeading) {
                        // Picture backgrounds keep the same backing color as the exported image.
                        (image == nil ? Color(nsColor: .textBackgroundColor) : Color.white)
                        if let image {
                            // Finder places the image at its native point size from the top left.
                            Image(nsImage: image)
                                .resizable()
                                .frame(width: image.size.width, height: image.size.height)
                        }
                        FinderPreviewItem(name: sourceURL?.deletingPathExtension().lastPathComponent ?? String(localized: "Your App"), path: sourceURL?.path, labelColor: labelColor, position: appPosition, bounds: CGSize(width: width, height: contentHeight))
                        if options.includeApplications {
                            FinderPreviewItem(name: "Applications", path: "/Applications", isAlias: true, labelColor: labelColor, position: applicationsPosition, bounds: CGSize(width: width, height: contentHeight))
                        }
                        ForEach($options.extraItems) { $extra in
                            FinderPreviewItem(name: extra.name, path: extra.url.path, labelColor: labelColor, position: Binding(get: { CGPoint(x: extra.x, y: extra.y) }, set: { extra.x = $0.x; extra.y = $0.y }), bounds: CGSize(width: width, height: contentHeight))
                        }
                    }
                    .frame(width: width, height: contentHeight, alignment: .topLeading)
                    .coordinateSpace(name: "finderContent")
                    .clipped()
                }
                .frame(width: width, height: height)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.primary.opacity(0.12)))
                .shadow(color: .black.opacity(0.15), radius: 16, y: 8)
                .scaleEffect(scale, anchor: .topLeading)
                .frame(width: width * scale, height: height * scale, alignment: .topLeading)
                .padding(32)
                .frame(minWidth: geometry.size.width, minHeight: geometry.size.height)
            }
        }
    }

    private var appPosition: Binding<CGPoint> {
        Binding(get: { CGPoint(x: options.appX, y: options.appY) }, set: { options.appX = $0.x; options.appY = $0.y })
    }

    private var applicationsPosition: Binding<CGPoint> {
        Binding(get: { CGPoint(x: options.applicationsX, y: options.applicationsY) }, set: { options.applicationsX = $0.x; options.applicationsY = $0.y })
    }
}

private struct FinderWindowPreview<Content: View>: View {
    let title: String
    let titleHeight: Double
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                ForEach([Color(red: 1, green: 0.37, blue: 0.35), Color(red: 1, green: 0.74, blue: 0.18), Color(red: 0.16, green: 0.79, blue: 0.25)], id: \.self) { color in
                    Circle().fill(color).overlay(Circle().strokeBorder(.black.opacity(0.12))).frame(width: 12, height: 12)
                }
                Spacer()
            }
            .padding(.horizontal, 10)
            .overlay {
                HStack(spacing: 5) {
                    Image(systemName: "externaldrive").foregroundStyle(.secondary)
                    Text(title).fontWeight(.semibold)
                }.font(.system(size: 13)).lineLimit(1).padding(.horizontal, 80)
            }
            .frame(height: titleHeight)
            .background(Color(nsColor: .windowBackgroundColor))
            content
        }
    }
}

private struct FinderPreviewItem: View {
    let name: String
    let path: String?
    var isAlias = false
    var labelColor: Color = .primary
    @Binding var position: CGPoint
    let bounds: CGSize
    @State private var dragOrigin: CGPoint?

    // Read the same defaults AppDMG writes to icvp rather than inventing preview sizes.
    private let metrics = Record.icvpRecord.Value()

    var body: some View {
        Group {
            if let path {
                Image(nsImage: NSWorkspace.shared.icon(forFile: path)).resizable()
            } else {
                Image(systemName: "app.fill").resizable().foregroundStyle(.blue)
            }
        }
        .frame(width: metrics.iconSize, height: metrics.iconSize)
        .overlay(alignment: .bottomLeading) {
            if isAlias {
                Image(systemName: "arrowshape.turn.up.right.fill")
                    .font(.system(size: 18, weight: .bold)).foregroundStyle(.black.opacity(0.8))
                    .frame(width: 28, height: 28)
                    .background(.white.opacity(0.95), in: Circle())
                    .overlay(Circle().strokeBorder(.black.opacity(0.15)))
                    .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
            }
        }
        .overlay(alignment: .top) {
            Text(name).font(.system(size: Double(metrics.textSize))).foregroundStyle(labelColor)
                .lineLimit(2).multilineTextAlignment(.center).frame(width: 148)
                .offset(y: metrics.iconSize + 8)
        }
        .contentShape(Rectangle())
        .position(position)
        .gesture(DragGesture(minimumDistance: 1, coordinateSpace: .named("finderContent"))
            .onChanged { value in
                let origin = dragOrigin ?? position
                dragOrigin = origin
                position = CGPoint(x: min(max(origin.x + value.translation.width, 0), bounds.width), y: min(max(origin.y + value.translation.height, 0), bounds.height))
            }
            .onEnded { _ in dragOrigin = nil })
        .help("Drag to reposition \(name)")
        .accessibilityLabel("\(name) icon position")
    }
}

#Preview("Finder Layout") {
    PreviewCanvas(options: .constant(.init()), sourceURL: nil, isBuilding: false).frame(width: 780, height: 640)
}

#Preview("Finder Layout — Dark") {
    PreviewCanvas(options: .constant(.init()), sourceURL: nil, isBuilding: false)
        .environment(\.colorScheme, .dark)
        .frame(width: 780, height: 640)
}
