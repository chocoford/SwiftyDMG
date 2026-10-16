import SwiftUI

struct CheckForUpdatesView: View {
    @ObservedObject var updates: UpdateController
    var body: some View {
        Button(.localizable(.updatesCheck), action: updates.check).disabled(!updates.canCheck)
    }
}

struct UpdateSettingsView: View {
    @ObservedObject var updates: UpdateController
    var body: some View {
        Form {
            Section(.localizable(.updatesSection)) {
                Toggle(.localizable(.updatesAutomaticChecks), isOn: Binding(get: { updates.automaticChecks }, set: updates.setAutomaticChecks))
                Toggle(.localizable(.updatesAutomaticDownloads), isOn: Binding(get: { updates.automaticDownloads }, set: updates.setAutomaticDownloads))
                CheckForUpdatesView(updates: updates)
            }.disabled(!updates.isConfigured)
            if !updates.isConfigured {
                Text(.localizable(.updatesDisabledMessage))
                    .foregroundStyle(.secondary)
            }
            Section(.localizable(.finderServiceSection)) {
                Text(.localizable(.finderServiceInstructions))
                Text(.localizable(.finderServiceEnableHelp))
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 470)
    }
}
