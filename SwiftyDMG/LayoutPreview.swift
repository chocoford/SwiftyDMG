import AppKit
import SwiftUI

struct LayoutPreview: View {
    @Binding var options: PackagingOptions
    var sourceURL: URL?

    var body: some View {
        GeometryReader { geometry in
            let width = options.windowWidth.isFinite ? max(320, options.windowWidth) : 660
            let height = options.windowHeight.isFinite ? max(240, options.windowHeight) : 400
            let scale = max(0.05, min(geometry.size.width / width, (geometry.size.height - 28) / height))
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    ForEach([Color.red, Color.yellow, Color.green], id: \.self) { color in
                        Circle().fill(color.opacity(0.8)).frame(width: 9, height: 9)
                    }
                    Spacer()
                    Text(sourceURL?.deletingPathExtension().lastPathComponent ?? "安装镜像").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                }.padding(.horizontal, 12).frame(height: 28).background(.regularMaterial)
                ZStack(alignment: .topLeading) {
                    Color.white
                    if let backgroundImage {
                        Image(nsImage: backgroundImage).resizable().scaledToFill()
                            .frame(width: width * scale, height: height * scale).clipped()
                    }
                    item(name: sourceURL?.lastPathComponent ?? "Your App.app", path: sourceURL?.path, symbol: "app.fill", scale: scale)
                        .position(x: options.appX * scale, y: options.appY * scale)
                        .gesture(drag(scale: scale) { options.appX = $0.x; options.appY = $0.y })
                        .accessibilityLabel("App 图标位置")
                    if options.includeApplications {
                        item(name: "Applications", path: "/Applications", symbol: "folder.fill", scale: scale)
                            .position(x: options.applicationsX * scale, y: options.applicationsY * scale)
                            .gesture(drag(scale: scale) { options.applicationsX = $0.x; options.applicationsY = $0.y })
                            .accessibilityLabel("Applications 链接位置")
                    }
                    ForEach($options.extraItems) { $extra in
                        item(name: extra.name, path: extra.url.path, symbol: "doc.fill", scale: scale)
                            .position(x: extra.x * scale, y: extra.y * scale)
                            .gesture(drag(scale: scale) { extra.x = $0.x; extra.y = $0.y })
                    }
                }
                .coordinateSpace(name: "dmgLayout")
                .frame(width: width * scale, height: height * scale)
                .clipped()
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.black.opacity(0.1)))
            .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var backgroundImage: NSImage? {
        switch options.background {
        case .none: return nil
        case .custom: return options.backgroundURL.flatMap { NSImage(contentsOf: $0) }
        case .automatic:
            return Bundle.main.url(forResource: "dmg-background", withExtension: "tiff").flatMap { NSImage(contentsOf: $0) }
        }
    }

    private func item(name: String, path: String?, symbol: String, scale: Double) -> some View {
        VStack(spacing: 4) {
            if let path {
                Image(nsImage: NSWorkspace.shared.icon(forFile: path)).resizable().frame(width: 72 * scale, height: 72 * scale)
            } else {
                Image(systemName: symbol).resizable().scaledToFit().foregroundStyle(.blue)
                    .frame(width: 72 * scale, height: 72 * scale)
            }
            Text(name).font(.system(size: max(9, 12 * scale))).foregroundStyle(.black)
                .lineLimit(2).multilineTextAlignment(.center)
        }.frame(width: 130 * scale).contentShape(Rectangle())
    }

    private func drag(scale: Double, update: @escaping (CGPoint) -> Void) -> some Gesture {
        DragGesture(coordinateSpace: .named("dmgLayout"))
            .onChanged { value in
                update(CGPoint(x: min(max(value.location.x / scale, 0), options.windowWidth),
                               y: min(max(value.location.y / scale, 0), options.windowHeight)))
            }
    }
}
