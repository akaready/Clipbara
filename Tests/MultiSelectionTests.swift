import XCTest

@MainActor
final class MultiSelectionTests: XCTestCase {
    private func state(at index: Int = 0) -> SearchState {
        let state = SearchState()
        state.select(index)
        return state
    }

    func testPlainSelectIsSingle() {
        let state = state(at: 2)
        XCTAssertFalse(state.hasMultiSelection)
        XCTAssertTrue(state.isSelected(2))
        XCTAssertFalse(state.isSelected(1))
    }

    func testToggleAddsAndRemoves() {
        let state = state(at: 1)
        state.toggle(3)
        XCTAssertEqual(state.selectedIndices, [1, 3])
        XCTAssertEqual(state.selectedIndex, 3)
        state.toggle(1)
        XCTAssertFalse(state.hasMultiSelection)
        XCTAssertEqual(state.selectedIndex, 3)
        XCTAssertTrue(state.isSelected(3))
    }

    func testToggleCannotEmptyTheSelection() {
        let state = state(at: 1)
        state.toggle(1)
        XCTAssertTrue(state.isSelected(1))
    }

    func testShiftRangeFromAnchorBothDirections() {
        let state = state(at: 2)
        state.extend(to: 5)
        XCTAssertEqual(state.selectedIndices, [2, 3, 4, 5])
        state.extend(to: 0)
        XCTAssertEqual(state.selectedIndices, [0, 1, 2])
        state.extend(to: 2)
        XCTAssertFalse(state.hasMultiSelection)
    }

    func testShiftArrowExtendsAndClamps() {
        let state = state(at: 1)
        state.extend(by: 1, maxIndex: 2)
        state.extend(by: 1, maxIndex: 2)
        XCTAssertEqual(state.selectedIndices, [1, 2])
        state.extend(by: -1, maxIndex: 2)
        XCTAssertFalse(state.hasMultiSelection)
        XCTAssertEqual(state.selectedIndex, 1)
    }

    func testSelectAllAndCollapse() {
        let state = state(at: 1)
        state.selectAll(count: 4)
        XCTAssertEqual(state.selectedIndices, [0, 1, 2, 3])
        state.collapse()
        XCTAssertFalse(state.hasMultiSelection)
        XCTAssertEqual(state.selectedIndex, 1)
    }

    func testMovingAndSearchingResetToSingle() {
        let state = state(at: 0)
        state.extend(to: 2)
        state.moveSelection(by: 1, maxIndex: 5)
        XCTAssertFalse(state.hasMultiSelection)
        state.extend(to: 4)
        state.updateSearch("x")
        XCTAssertFalse(state.hasMultiSelection)
        XCTAssertNil(state.selectedIndex)
    }

    func testShrinkingListDropsMultiSelection() {
        let state = state(at: 0)
        state.extend(to: 3)
        state.ensureSelection(itemCount: 2)
        XCTAssertFalse(state.hasMultiSelection)
        XCTAssertEqual(state.selectedIndex, 1)
    }
}
