import Foundation

@MainActor
struct RelativeTimeFormatter {
    private static let formatter: Foundation.RelativeDateTimeFormatter = {
        let f = Foundation.RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    private static let fullFormatter: Foundation.RelativeDateTimeFormatter = {
        let f = Foundation.RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f
    }()

    /// `full` spells units out ("3 minutes ago") instead of abbreviating ("3 min. ago").
    static func string(for date: Date, full: Bool = false) -> String {
        (full ? fullFormatter : formatter).localizedString(for: date, relativeTo: Date())
    }
}
