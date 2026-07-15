import XCTest
@testable import gh_notch

final class InterceptSafetyTests: XCTestCase {

    private typealias Safety = InterceptSafety

    func testStartsIntercepting() {
        XCTAssertTrue(Safety.isIntercepting(.armed, keyClass: .volume))
    }

    func testSuccessfulChangeKeepsIntercepting() {
        var s = InterceptSafety.State.armed
        for _ in 0..<5 {
            s = Safety.recording(s, keyClass: .volume, changed: true, atRail: false)
        }
        XCTAssertTrue(Safety.isIntercepting(s, keyClass: .volume))
    }

    func testTwoRealFailuresDisableClass() {
        var s = InterceptSafety.State.armed
        s = Safety.recording(s, keyClass: .volume, changed: false, atRail: false)
        XCTAssertTrue(Safety.isIntercepting(s, keyClass: .volume)) // one fluke tolerated
        s = Safety.recording(s, keyClass: .volume, changed: false, atRail: false)
        XCTAssertFalse(Safety.isIntercepting(s, keyClass: .volume)) // second → disabled
    }

    func testAtRailNoChangeIsNotAFailure() {
        var s = InterceptSafety.State.armed
        // Pressing volume-up at 100% legitimately changes nothing — must never disable.
        for _ in 0..<5 {
            s = Safety.recording(s, keyClass: .volume, changed: false, atRail: true)
        }
        XCTAssertTrue(Safety.isIntercepting(s, keyClass: .volume))
    }

    func testSuccessResetsFailureStreak() {
        var s = InterceptSafety.State.armed
        s = Safety.recording(s, keyClass: .brightness, changed: false, atRail: false)
        s = Safety.recording(s, keyClass: .brightness, changed: true, atRail: false)  // reset
        s = Safety.recording(s, keyClass: .brightness, changed: false, atRail: false) // count 1 again
        XCTAssertTrue(Safety.isIntercepting(s, keyClass: .brightness))
    }

    func testFailuresArePerKeyClass() {
        var s = InterceptSafety.State.armed
        s = Safety.recording(s, keyClass: .volume, changed: false, atRail: false)
        s = Safety.recording(s, keyClass: .volume, changed: false, atRail: false)
        XCTAssertFalse(Safety.isIntercepting(s, keyClass: .volume))
        XCTAssertTrue(Safety.isIntercepting(s, keyClass: .brightness)) // untouched
    }

    func testResetReArmsEverything() {
        var s = InterceptSafety.State.armed
        s = Safety.recording(s, keyClass: .volume, changed: false, atRail: false)
        s = Safety.recording(s, keyClass: .volume, changed: false, atRail: false)
        XCTAssertFalse(Safety.isIntercepting(s, keyClass: .volume))
        s = Safety.reset(s)
        XCTAssertTrue(Safety.isIntercepting(s, keyClass: .volume))
    }
}
