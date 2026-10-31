import XCTest

final class PanelResumeTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000)

    func testResetsWhenNeverHidden() {
        XCTAssertTrue(PanelResumePolicy.shouldReset(hiddenAt: nil, now: now, window: 5))
    }

    func testResetsWhenWindowIsZero() {
        XCTAssertTrue(PanelResumePolicy.shouldReset(hiddenAt: now, now: now, window: 0))
    }

    func testResumesInsideWindow() {
        XCTAssertFalse(PanelResumePolicy.shouldReset(hiddenAt: now.addingTimeInterval(-4), now: now, window: 5))
    }

    func testResetsOnceWindowElapsed() {
        XCTAssertTrue(PanelResumePolicy.shouldReset(hiddenAt: now.addingTimeInterval(-5), now: now, window: 5))
    }
}
