import SwiftUI

@MainActor
@Observable
final class SearchState {
    var searchText: String = ""
    var debouncedSearchText: String = ""
    var selectedContentTypes: Set<ContentType> = []
    var dateFilter: DateFilter = .all
    /// The cursor: the card keyboard actions start from. With a multi-selection
    /// it is the most recently clicked or extended card.
    var selectedIndex: Int? = nil
    /// Every selected card, only while 2 or more are selected. Empty means the
    /// selection is just `selectedIndex`.
    private(set) var selectedIndices: Set<Int> = []
    /// Where a ⇧ range starts from.
    private(set) var anchorIndex: Int?

    private var debounceTask: Task<Void, Never>?

    enum DateFilter: String, CaseIterable, Sendable {
        case all = "All"
        case today = "Today"
        case thisWeek = "This Week"
        case thisMonth = "This Month"

        /// Localized menu title. `rawValue` stays the stable English identifier.
        var displayName: String {
            switch self {
            case .all: String(localized: "All")
            case .today: String(localized: "Today")
            case .thisWeek: String(localized: "This Week")
            case .thisMonth: String(localized: "This Month")
            }
        }

        var startDate: Date? {
            let calendar = Calendar.current
            switch self {
            case .all: return nil
            case .today: return calendar.startOfDay(for: Date())
            case .thisWeek:
                return calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))
            case .thisMonth:
                return calendar.date(from: calendar.dateComponents([.year, .month], from: Date()))
            }
        }
    }

    var isActive: Bool {
        !searchText.isEmpty || !selectedContentTypes.isEmpty || dateFilter != .all
    }

    func updateSearch(_ text: String) {
        // The field writes its text back when it loses focus. Same text, same
        // results: keep the selection (Tab out of the field relies on it).
        guard text != searchText else { return }
        searchText = text
        select(nil)
        debounceTask?.cancel()
        debounceTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            debouncedSearchText = text
        }
    }

    func reset() {
        searchText = ""
        debouncedSearchText = ""
        selectedContentTypes = []
        dateFilter = .all
        select(nil)
        debounceTask?.cancel()
    }

    func clearSearch() {
        searchText = ""
        debouncedSearchText = ""
        select(nil)
        debounceTask?.cancel()
    }

    func toggleContentType(_ type: ContentType) {
        if selectedContentTypes.contains(type) {
            selectedContentTypes.remove(type)
        } else {
            selectedContentTypes.insert(type)
        }
        select(nil)
    }

    func filteredItems(from items: [ClipboardItem]) -> [ClipboardItem] {
        let startDate = dateFilter.startDate
        let contentTypes = selectedContentTypes
        let query = debouncedSearchText

        guard startDate != nil || !contentTypes.isEmpty || !query.isEmpty else {
            return items
        }

        return items.filter { item in
            if let startDate, item.copiedAt < startDate {
                return false
            }

            if !contentTypes.isEmpty, !contentTypes.contains(item.contentType) {
                return false
            }

            if !query.isEmpty {
                return item.matchesSearchQuery(query)
            }

            return true
        }
    }

    func moveSelection(by offset: Int, maxIndex: Int) {
        guard maxIndex >= 0 else { select(nil); return }
        if let current = selectedIndex {
            select(max(0, min(current + offset, maxIndex)))
        } else {
            select(0)
        }
    }

    func ensureSelection(itemCount: Int) {
        guard itemCount > 0 else {
            select(nil)
            return
        }

        guard let current = selectedIndex else {
            select(0)
            return
        }
        let clamped = max(0, min(current, itemCount - 1))
        if selectedIndices.contains(where: { $0 >= itemCount }) {
            // The list shrank under a multi-selection; fall back to the cursor.
            select(clamped)
        } else {
            selectedIndex = clamped
        }
    }

    // MARK: - Multi-selection

    var hasMultiSelection: Bool { selectedIndices.count > 1 }

    func isSelected(_ index: Int) -> Bool {
        selectedIndices.isEmpty ? selectedIndex == index : selectedIndices.contains(index)
    }

    /// Plain selection of one card (or none); drops any multi-selection.
    func select(_ index: Int?) {
        selectedIndex = index
        anchorIndex = index
        selectedIndices = []
    }

    /// ⌘-click: adds the card to the selection, or takes it out again.
    func toggle(_ index: Int) {
        var set = selectedIndices.isEmpty ? Set(selectedIndex.map { [$0] } ?? []) : selectedIndices
        if set.contains(index) {
            guard set.count > 1 else { return }
            set.remove(index)
            if selectedIndex == index { selectedIndex = set.max() }
        } else {
            set.insert(index)
            selectedIndex = index
        }
        anchorIndex = index
        selectedIndices = set.count > 1 ? set : []
        if set.count == 1 { selectedIndex = set.first }
    }

    /// ⇧-click: selects everything from the anchor to `index`.
    func extend(to index: Int) {
        let anchor = anchorIndex ?? selectedIndex ?? index
        selectedIndex = index
        anchorIndex = anchor
        let range = Set(min(anchor, index)...max(anchor, index))
        selectedIndices = range.count > 1 ? range : []
    }

    /// ⇧+←/→.
    func extend(by offset: Int, maxIndex: Int) {
        guard maxIndex >= 0 else { return }
        extend(to: max(0, min((selectedIndex ?? 0) + offset, maxIndex)))
    }

    func selectAll(count: Int) {
        guard count > 0 else { return }
        selectedIndex = selectedIndex.map { min($0, count - 1) } ?? 0
        anchorIndex = 0
        selectedIndices = count > 1 ? Set(0..<count) : []
    }

    /// Escape: back to the single card under the cursor.
    func collapse() {
        select(selectedIndex)
    }
}

private extension ClipboardItem {
    func matchesSearchQuery(_ query: String) -> Bool {
        // Source app names are left out: the card doesn't show the app name,
        // so a clip matching only through it (a clip from "Aside" for "a")
        // looked like a wrong result.
        textContent?.localizedCaseInsensitiveContains(query) == true ||
        userTitle?.localizedCaseInsensitiveContains(query) == true
    }
}
