import SwiftUI

struct WelcomeView: View {
    @Environment(\.dismissWindow) private var dismissWindow
    let open: () -> Void
    let select: (URL) -> Bool
    @State private var isTargeted = false

    var body: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: 12) {
                welcomeContent
            }
        } else {
            welcomeContent
        }
    }

    private var welcomeContent: some View {
        VStack(spacing: 18) {
            Image(systemName: "externaldrive.badge.plus")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(isTargeted ? Color.accentColor : Color.secondary)
                .symbolRenderingMode(.hierarchical)
            VStack(spacing: 8) {
                Text(.localizable(.welcomeTitle)).font(.title2.weight(.semibold))
                Text(.localizable(.welcomeSubtitle))
                    .font(.callout).foregroundStyle(.secondary)
            }
            openButton
                .controlSize(.large)
                .keyboardShortcut("o")
                .accessibilityIdentifier("openAppButton")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .topLeading) {
            closeButton.padding(16)
        }
        .ignoresSafeArea(.container, edges: .top)
        .dropDestination(for: URL.self) { urls, _ in
            guard urls.count == 1 else { return false }
            return select(urls[0])
        } isTargeted: { isTargeted = $0 }
        .accessibilityIdentifier("appDropArea")
    }

    @ViewBuilder
    private var closeButton: some View {
        if #available(macOS 26.0, *) {
            closeActionButton.buttonStyle(.glass)
        } else {
            closeActionButton.buttonStyle(.bordered)
        }
    }

    private var closeActionButton: some View {
        Button { dismissWindow() } label: {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 14, height: 14)
        }
        .buttonBorderShape(.circle)
        .controlSize(.small)
        .frame(width: 28, height: 28)
        .help(String(localizable: .generalButtonClose))
        .accessibilityLabel(.localizable(.generalButtonClose))
        .accessibilityIdentifier("closeWelcomeWindowButton")
    }

    @ViewBuilder
    private var openButton: some View {
        if #available(macOS 26.0, *) {
            Button(.localizable(.generalButtonOpen), action: open).buttonStyle(.glass)
        } else {
            Button(.localizable(.generalButtonOpen), action: open).buttonStyle(.bordered)
        }
    }
}

#Preview {
    WelcomeView(open: {}, select: { _ in true }).frame(width: 400, height: 300)
}
