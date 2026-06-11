import XCTest
@testable import gh_notch

final class ClockModelTests: XCTestCase {

    func testNowReflectsInjectedClock() {
        let fixed = Date(timeIntervalSince1970: 0)
        let model = ClockModel(clock: { fixed })
        XCTAssertEqual(model.now, fixed)
    }

    func testTimeAndDateTextAreNonEmpty() {
        let fixed = Date(timeIntervalSince1970: 1_700_000_000)
        let model = ClockModel(clock: { fixed })
        XCTAssertFalse(model.timeText.isEmpty)
        XCTAssertFalse(model.dateText.isEmpty)
    }
}
