import AppKit
import SwiftUI

enum InspectorTab: String, CaseIterable, Identifiable {
    case settings, activity
    var id: Self { self }
    var title: LocalizedStringKey { self == .settings ? .localizable(.inspectorTabSettings) : .localizable(.inspectorTabBuild) }
    var symbol: String { self == .settings ? "slider.horizontal.3" : "list.bullet.rectangle" }
}

struct InspectorTabPicker: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var selection: InspectorTab
    @Namespace private var selectionAnimation

    var body: some View {
        HStack(spacing: 2) {
            ForEach(InspectorTab.allCases) { tab in
                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                        selection = tab
                    }
                } label: {
                    Label(tab.title, systemImage: tab.symbol)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(selection == tab ? Color.primary : Color.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background {
                            if selection == tab {
                                Capsule()
                                    .fill(Color(nsColor: .controlBackgroundColor))
                                    .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
                                    .matchedGeometryEffect(id: "inspectorSelection", in: selectionAnimation)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
                .accessibilityIdentifier("inspectorTab_\(tab.rawValue)")
            }
        }
        .padding(3)
        .background(.quaternary.opacity(0.5), in: Capsule())
        .accessibilityElement(children: .contain)
        .accessibilityLabel(.localizable(.toolbarInspector))
    }
}
