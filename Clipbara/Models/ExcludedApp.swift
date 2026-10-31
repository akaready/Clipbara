import AppKit
import SwiftData

@Model
final class ExcludedApp {

    var bundleId: String
    var appName: String

    init(bundleId: String, appName: String) {
        self.bundleId = bundleId
        self.appName = appName
    }

    /// Reads the bundle id and display name from an app bundle. Shared by the
    /// "+" picker and the default password manager seeding.
    static func make(appAt url: URL) -> ExcludedApp? {
        guard let bundle = Bundle(url: url),
              let bundleId = bundle.bundleIdentifier else { return nil }

        let appName = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? url.deletingPathExtension().lastPathComponent
        return ExcludedApp(bundleId: bundleId, appName: appName)
    }

    static let passwordManagerBundleIds = [
        "com.apple.Passwords",
        "com.apple.keychainaccess",
        "com.1password.1password",
        "com.agilebits.onepassword7",
        "com.bitwarden.desktop",
        "me.proton.pass.electron",
        "com.lastpass.LastPass",
        "com.dashlane.dashlanephonefinal",
        "in.sinew.Enpass-Desktop",
        "org.keepassxc.keepassxc",
        "com.callpod.keepermac.lite",
        "com.nordpass.macos.NordPass",
    ]

    /// Excludes the installed password managers, once. The flag is only set after a
    /// successful save, so a failed save retries on the next launch. Users who remove
    /// an entry later are never re-seeded.
    @MainActor
    static func seedPasswordManagersOnce(in context: ModelContext, defaults: UserDefaults = .standard) {
        let key = "didSeedPasswordManagerExclusions"
        guard !defaults.bool(forKey: key) else { return }

        let existing = Set(((try? context.fetch(FetchDescriptor<ExcludedApp>())) ?? []).map(\.bundleId))
        for bundleId in passwordManagerBundleIds where !existing.contains(bundleId) {
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId),
                  let app = make(appAt: url) else { continue }
            context.insert(app)
        }

        do {
            try context.save()
            defaults.set(true, forKey: key)
        } catch {
            context.rollback()
        }
    }
}
