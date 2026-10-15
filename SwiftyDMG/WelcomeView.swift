import SwiftUI

struct WelcomeView: View {
    let open: () -> Void
    let select: (URL) -> Bool
    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "externaldrive.badge.plus")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(isTargeted ? Color.accentColor : Color.secondary)
                .symbolRenderingMode(.hierarchical)
            VStack(spacing: 8) {
                Text("Drop Your App Here").font(.title2.weight(.semibold))
                Text("Create a disk image for your macOS app")
                    .font(.callout).foregroundStyle(.secondary)
            }
            openButton
                .controlSize(.large)
                .keyboardShortcut("o")
                .accessibilityIdentifier("openAppButton")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
        .ignoresSafeArea(.container, edges: .top)
        .dropDestination(for: URL.self) { urls, _ in
            guard urls.count == 1 else { return false }
            return select(urls[0])
        } isTargeted: { isTargeted = $0 }
        .accessibilityIdentifier("appDropArea")
    }

    @ViewBuilder
    private var openButton: some View {
        if #available(macOS 26.0, *) {
            Button("Open…", action: open).buttonStyle(.glass)
        } else {
            Button("Open…", action: open).buttonStyle(.bordered)
        }
    }
}

#Preview {
    WelcomeView(open: {}, select: { _ in true }).frame(width: 400, height: 300)
}
