import AppKit
import SwiftUI

enum PreviewZoom: String, CaseIterable, Identifiable {
    case fit, half, actual, double
    var id: Self { self }
    var title: String {
        switch self {
        case .fit: String(localizable: .previewFitToWindow)
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
        case .system: .localizable(.previewAppearanceSystem)
        case .light: .localizable(.previewAppearanceLight)
        case .dark: .localizable(.previewAppearanceDark)
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
                Picker(.localizable(.previewZoom), selection: $zoom) {
                    ForEach(PreviewZoom.allCases) { Text(verbatim: $0.title).tag($0) }
                }
                .labelsHidden().frame(width: 110)
                Menu {
                    Picker(.localizable(.previewAppearance), selection: $appearance) {
                        ForEach(PreviewAppearance.allCases) { mode in
                            Label(mode.title, systemImage: mode.symbol).tag(mode)
                        }
                    }
                } label: {
                    Label(.localizable(.previewAppearance), systemImage: appearance.symbol)
                }
                .labelStyle(.iconOnly)
                .help(String(localizable: .previewAppearanceHelp))
                .accessibilityIdentifier("previewAppearanceMenu")
                Spacer()
                Text(.localizable(.previewLayoutHelp)).foregroundStyle(.secondary)
                    .lineLimit(1).layoutPriority(-1)
                Spacer()
                Text(verbatim: "\(options.windowWidth.formatted(.number.precision(.fractionLength(0)))) × \(options.windowHeight.formatted(.number.precision(.fractionLength(0))))")
                    .monospacedDigit().foregroundStyle(.secondary).lineLimit(1)
            }
            .font(.caption).controlSize(.small).padding(14)
        }
        .background(Color(nsColor: .underPageBackgroundColor))
    }
}
