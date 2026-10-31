import Foundation

enum PanelResumePolicy {
    /// Reopening within the resume window picks up where the panel was hidden.
    /// A window of 0 always resets.
    static func shouldReset(hiddenAt: Date?, now: Date, window: TimeInterval) -> Bool {
        guard let hiddenAt, window > 0 else { return true }
        return now.timeIntervalSince(hiddenAt) >= window
    }
}
