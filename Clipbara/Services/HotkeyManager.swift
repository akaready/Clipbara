import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleHistoryPanel = Self(
        "toggleHistoryPanel",
        initial: .init(.v, modifiers: [.shift, .command])
    )
    /// No default: users pick one in the welcome tour or Settings.
    static let toggleClipQueue = Self("toggleClipQueue")
    /// Pastes the newest clip as plain text from anywhere, without opening the panel.
    /// No default: users pick one in Settings.
    static let pasteLatestAsPlainText = Self("pasteLatestAsPlainText")
    static let clearHistory = Self(
        "clearHistory",
        initial: .init(.delete, modifiers: [.shift, .command])
    )
}
