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
    @AppStorage(PanelController.fitImageCardsDefaultsKey) private var fitImageCards: Bool = false
    @AppStorage(PanelController.cardStyleDefaultsKey) private var cardStyle: CardStyle = .classic
    @AppStorage(PanelController.panelBackgroundDefaultsKey) private var panelBackground: PanelBackground = .solid
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

            Picker(selection: $cardStyle) {
                Text("Classic").tag(CardStyle.classic)
                Text("Colorful").tag(CardStyle.colorful)
            } label: {
                Text("Card Style")
                Text("Colorful tints each card by its content or source app.")
            }
            .pickerStyle(.segmented)

            Picker(selection: $panelBackground) {
                Text("Solid").tag(PanelBackground.solid)
                Text("Glass").tag(PanelBackground.glass)
            } label: {
                Text("Panel Background")
                Text("Glass lets the desktop show through the panel.")
            }
            .pickerStyle(.segmented)

            Picker(selection: $fullWidth) {
                Text("Standard").tag(false)
                Text("Full width").tag(true)
            } label: {
                Text("Panel Width")
                Text("Full width spans the whole screen.")
            }
            .pickerStyle(.segmented)

            Picker(selection: $cardScale) {
                Text("Small").tag(0.85)
                Text("Medium").tag(1.0)
                Text("Large").tag(1.25)
                Text("Extra large").tag(1.5)
            } label: {
                Text("Card Size")
                Text("Scales the cards and the panel height.")
            }
            .pickerStyle(.segmented)

            Toggle(isOn: $fitImageCards) {
                Text("Fill image cards")
                Text("Images fill the whole card instead of fitting inside it.")
            }

            Toggle(isOn: $animatesPanel) {
                Text("Animate Panel")
                if reducesMotion {
                    Text("Off while Reduce Motion is on in System Settings > Accessibility > Display.")
                } else {
                    Text("Slide the history panel in and out. When off, it appears and closes at once.")
                }
            }
            .disabled(reducesMotion)
            .onReceive(NSWorkspace.shared.notificationCenter.publisher(
                for: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification
            )) { _ in
                reducesMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            }
        }
        .formStyle(.grouped)
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
