import SwiftUI
import SwiftData

struct ExclusionSettingsTab: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ExcludedApp.appName) private var excludedApps: [ExcludedApp]
    @Environment(AppState.self) private var appState
    @State private var selection: ExcludedApp?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Excluded apps will not have their clipboard content saved.")
                .font(.callout)
                .foregroundStyle(.secondary)

            List(excludedApps, selection: $selection) { app in
                HStack {
                    Image(nsImage: AppIconProvider.icon(for: app.bundleId, size: 24))
                        .resizable()
                        .frame(width: 24, height: 24)
                    Text(app.appName)
                    Spacer()
                    Text(app.bundleId)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .tag(app)
            }
            .listStyle(.bordered)
            .frame(minHeight: 160)

            HStack {
                Button {
                    addApp()
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 28, height: 22)
                }

                Button {
                    removeSelected()
                } label: {
                    Image(systemName: "minus")
                        .frame(width: 28, height: 22)
                }
                .disabled(selection == nil)

                Spacer()
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
        }
        .padding()
    }

    private func addApp() {
        let panel = NSOpenPanel()
        panel.title = String(localized: "Select App to Exclude")
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url,
              let excluded = ExcludedApp.make(appAt: url) else { return }

        // Check duplicate
        if excludedApps.contains(where: { $0.bundleId == excluded.bundleId }) { return }

        modelContext.insert(excluded)
        try? modelContext.save()
        appState.clipboardMonitor.loadExcludedApps()
    }

    private func removeSelected() {
        guard let app = selection else { return }
        modelContext.delete(app)
        try? modelContext.save()
        selection = nil
        appState.clipboardMonitor.loadExcludedApps()
    }
}
