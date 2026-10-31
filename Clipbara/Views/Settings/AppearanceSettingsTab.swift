import SwiftUI

enum AppTheme: String, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    /// Localized label. `rawValue` is what is stored in UserDefaults.
    var displayName: String {
        switch self {
        case .system: String(localized: "System")
        case .light: String(localized: "Light")
        case .dark: String(localized: "Dark")
        }
    }
}

struct AppearanceSettingsTab: View {
    @AppStorage("appTheme") private var appTheme: String = AppTheme.system.rawValue
    @AppStorage(PanelController.animatesPanelDefaultsKey) private var animatesPanel: Bool = true
    @AppStorage(PanelController.fullWidthDefaultsKey) private var fullWidth: Bool = false
    @AppStorage(PanelController.cardScaleDefaultsKey) private var cardScale: Double = 1
    @State private var reducesMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

    var body: some View {
        Form {
            Picker("Theme", selection: $appTheme) {
                ForEach(AppTheme.allCases, id: \.rawValue) { theme in
                    Text(theme.displayName).tag(theme.rawValue)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: appTheme) { _, newValue in
                applyTheme(newValue)
            }

            Picker("Panel Width", selection: $fullWidth) {
                Text("Fit content").tag(false)
                Text("Full width").tag(true)
            }
            .pickerStyle(.segmented)

            Picker("Card Size", selection: $cardScale) {
                Text("Small").tag(0.85)
                Text("Medium").tag(1.0)
                Text("Large").tag(1.25)
                Text("Extra large").tag(1.5)
            }
            .pickerStyle(.segmented)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Animate Panel")
                    Group {
                        if reducesMotion {
                            Text("Off while Reduce Motion is on in System Settings > Accessibility > Display.")
                        } else {
                            Text("Slide the history panel in and out. When off, it appears and closes at once.")
                        }
                    }
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Toggle("", isOn: $animatesPanel)
                    .labelsHidden()
                    .disabled(reducesMotion)
            }
            .onReceive(NSWorkspace.shared.notificationCenter.publisher(
                for: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification
            )) { _ in
                reducesMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            applyTheme(appTheme)
        }
    }

    private func applyTheme(_ theme: String) {
        switch AppTheme(rawValue: theme) {
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        default:
            NSApp.appearance = nil
        }
    }
}
