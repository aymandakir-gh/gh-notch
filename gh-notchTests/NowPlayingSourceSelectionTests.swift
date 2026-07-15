import XCTest
@testable import gh_notch

final class NowPlayingSourceSelectionTests: XCTestCase {

    private typealias Sel = NowPlayingSourceSelection

    func testPrefersAdapterWhenAvailable() {
        let pick = Sel.select(probes: [.adapter: true, .directMediaRemote: true, .appleScript: true])
        XCTAssertEqual(pick, .adapter)
    }

    func testFallsToDirectWhenAdapterFails() {
        let pick = Sel.select(probes: [.adapter: false, .directMediaRemote: true, .appleScript: true])
        XCTAssertEqual(pick, .directMediaRemote)
    }

    func testFallsToAppleScriptWhenOthersFail() {
        let pick = Sel.select(probes: [.adapter: false, .directMediaRemote: false, .appleScript: true])
        XCTAssertEqual(pick, .appleScript)
    }

    func testNoneAvailableIsNil() {
        XCTAssertNil(Sel.select(probes: [.adapter: false, .directMediaRemote: false, .appleScript: false]))
        XCTAssertNil(Sel.select(probes: [:]))  // no probes recorded yet
    }

    func testReselectPrefersRecoveredHigherPriority() {
        // Currently on AppleScript; the adapter recovers → switch back up.
        let pick = Sel.reselect(current: .appleScript,
                                probes: [.adapter: true, .directMediaRemote: false, .appleScript: true])
        XCTAssertEqual(pick, .adapter)
    }

    func testReselectDropsWhenCurrentFails() {
        // On adapter; it dies, direct is up → fall to direct.
        let pick = Sel.reselect(current: .adapter,
                                probes: [.adapter: false, .directMediaRemote: true, .appleScript: false])
        XCTAssertEqual(pick, .directMediaRemote)
    }

    func testOrderIsAdapterFirst() {
        XCTAssertEqual(Sel.order, [.adapter, .directMediaRemote, .appleScript])
    }

    // MARK: directMediaRemoteEligible (< 15.4)

    func testDirectEligibleOnOlderOS() {
        XCTAssertTrue(Sel.directMediaRemoteEligible(osMajor: 14, osMinor: 6))
        XCTAssertTrue(Sel.directMediaRemoteEligible(osMajor: 15, osMinor: 0))
        XCTAssertTrue(Sel.directMediaRemoteEligible(osMajor: 15, osMinor: 3))
    }

    func testDirectIneligibleAtOrAfter15_4() {
        XCTAssertFalse(Sel.directMediaRemoteEligible(osMajor: 15, osMinor: 4))
        XCTAssertFalse(Sel.directMediaRemoteEligible(osMajor: 15, osMinor: 5))
        XCTAssertFalse(Sel.directMediaRemoteEligible(osMajor: 26, osMinor: 0))
    }
}
