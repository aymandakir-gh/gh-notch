import XCTest
@testable import gh_notch

final class ActivityCenterLogicTests: XCTestCase {

    private typealias Logic = ActivityCenterLogic

    private func act(
        _ id: String,
        priority: Int = 0,
        postedAt: TimeInterval = 0,
        expiresAt: TimeInterval? = nil,
        dismiss: Activity.DismissBehavior = .remove
    ) -> Activity {
        Activity(
            id: id, kind: .timer, priority: priority, title: id,
            postedAt: postedAt, expiresAt: expiresAt, dismissBehavior: dismiss
        )
    }

    // MARK: ordered

    func testOrderedByPriorityThenRecencyThenID() {
        let ordered = Logic.ordered([
            act("low", priority: 1, postedAt: 5),
            act("highOld", priority: 10, postedAt: 1),
            act("highNew", priority: 10, postedAt: 9),
        ])
        XCTAssertEqual(ordered.map(\.id), ["highNew", "highOld", "low"])
    }

    func testOrderedIDTieBreakIsStable() {
        let ordered = Logic.ordered([
            act("b", priority: 0, postedAt: 0),
            act("a", priority: 0, postedAt: 0),
        ])
        XCTAssertEqual(ordered.map(\.id), ["a", "b"])
    }

    // MARK: posting / preemption

    func testPostIntoEmptyIsFrontmost() {
        let s = Logic.posting(act("a"), into: .empty)
        XCTAssertEqual(Logic.frontmost(s)?.id, "a")
        XCTAssertEqual(s.cycleIndex, 0)
    }

    func testHigherPriorityPostPreempts() {
        var s = Logic.posting(act("low", priority: 1, postedAt: 1), into: .empty)
        s = Logic.posting(act("high", priority: 9, postedAt: 2), into: s)
        XCTAssertEqual(Logic.frontmost(s)?.id, "high")
    }

    func testLowerPriorityPostDoesNotStealFocus() {
        var s = Logic.posting(act("high", priority: 9, postedAt: 1), into: .empty)
        s = Logic.posting(act("low", priority: 1, postedAt: 2), into: s)
        XCTAssertEqual(Logic.frontmost(s)?.id, "high")
        XCTAssertEqual(s.active.count, 2)
    }

    func testPostSameIDCoalesces() {
        var s = Logic.posting(act("a", postedAt: 1), into: .empty)
        var updated = act("a", postedAt: 2)
        updated.title = "updated"
        s = Logic.posting(updated, into: s)
        XCTAssertEqual(s.active.count, 1)
        XCTAssertEqual(Logic.frontmost(s)?.title, "updated")
    }

    // MARK: cycling

    func testCycleWrapsForwardAndBack() {
        var s = Logic.posting(act("a", postedAt: 3), into: .empty)
        s = Logic.posting(act("b", postedAt: 2), into: s)
        s = Logic.posting(act("c", postedAt: 1), into: s)
        // ordered [a,b,c], frontmost a
        XCTAssertEqual(Logic.frontmost(s)?.id, "a")
        s = Logic.cycled(s, forward: true)
        XCTAssertEqual(Logic.frontmost(s)?.id, "b")
        s = Logic.cycled(s, forward: true)
        XCTAssertEqual(Logic.frontmost(s)?.id, "c")
        s = Logic.cycled(s, forward: true) // wrap
        XCTAssertEqual(Logic.frontmost(s)?.id, "a")
        s = Logic.cycled(s, forward: false) // wrap back
        XCTAssertEqual(Logic.frontmost(s)?.id, "c")
    }

    func testCycleNoopWithZeroOrOne() {
        XCTAssertEqual(Logic.cycled(.empty, forward: true), .empty)
        let one = Logic.posting(act("a"), into: .empty)
        XCTAssertEqual(Logic.cycled(one, forward: true), one)
    }

    func testPostResetsCycleToFrontmost() {
        var s = Logic.posting(act("a", postedAt: 3), into: .empty)
        s = Logic.posting(act("b", postedAt: 2), into: s)
        s = Logic.cycled(s, forward: true)           // now on b
        s = Logic.posting(act("c", priority: 5, postedAt: 1), into: s) // preempts
        XCTAssertEqual(s.cycleIndex, 0)
        XCTAssertEqual(Logic.frontmost(s)?.id, "c")
    }

    // MARK: dismiss / restore

    func testDismissRemoveIsGone() {
        var s = Logic.posting(act("a", dismiss: .remove), into: .empty)
        s = Logic.dismissingFrontmost(s)
        XCTAssertTrue(s.active.isEmpty)
        XCTAssertTrue(s.dismissed.isEmpty)
    }

    func testDismissRestorableMovesToDismissedFront() {
        var s = Logic.posting(act("a", dismiss: .restorable), into: .empty)
        s = Logic.dismissingFrontmost(s)
        XCTAssertTrue(s.active.isEmpty)
        XCTAssertEqual(s.dismissed.map(\.id), ["a"])
    }

    func testDismissClampsIndex() {
        var s = Logic.posting(act("a", postedAt: 3), into: .empty)
        s = Logic.posting(act("b", postedAt: 2, dismiss: .restorable), into: s)
        s = Logic.posting(act("c", postedAt: 1, dismiss: .restorable), into: s)
        // ordered [a,b,c]; cycle to c (index 2)
        s = Logic.cycled(s, forward: true)
        s = Logic.cycled(s, forward: true)
        XCTAssertEqual(Logic.frontmost(s)?.id, "c")
        s = Logic.dismissingFrontmost(s) // removes c → [a,b], index clamps 2→1
        XCTAssertEqual(s.active.map(\.id), ["a", "b"])
        XCTAssertEqual(Logic.frontmost(s)?.id, "b")
        XCTAssertEqual(s.dismissed.map(\.id), ["c"])
    }

    func testRestoreBringsBackFrontmost() {
        var s = Logic.posting(act("a", priority: 9, postedAt: 2), into: .empty)
        s = Logic.posting(act("b", postedAt: 1, dismiss: .restorable), into: s)
        s = Logic.cycled(s, forward: true)          // focus b
        s = Logic.dismissingFrontmost(s)            // b → dismissed
        XCTAssertEqual(s.active.map(\.id), ["a"])
        s = Logic.restoring(id: "b", in: s)
        XCTAssertTrue(s.dismissed.isEmpty)
        XCTAssertTrue(s.active.contains { $0.id == "b" })
        XCTAssertEqual(Logic.frontmost(s)?.id, "b")  // restore is frontmost
    }

    func testRestoreUnknownIDIsNoop() {
        let s = Logic.posting(act("a"), into: .empty)
        XCTAssertEqual(Logic.restoring(id: "zzz", in: s), s)
    }

    func testPostRevivesDismissedSameID() {
        var s = Logic.posting(act("a", dismiss: .restorable), into: .empty)
        s = Logic.dismissingFrontmost(s)
        XCTAssertEqual(s.dismissed.map(\.id), ["a"])
        s = Logic.posting(act("a"), into: s)
        XCTAssertTrue(s.dismissed.isEmpty)      // no longer in restorable set
        XCTAssertEqual(s.active.map(\.id), ["a"])
    }

    // MARK: expiry

    func testExpiringRemovesPastDeadlineKeepsSticky() {
        var s = Logic.posting(act("expiring", postedAt: 0, expiresAt: 10), into: .empty)
        s = Logic.posting(act("sticky", postedAt: 0, expiresAt: nil), into: s)
        let after = Logic.expiring(s, now: 10)   // expiresAt <= now removed
        XCTAssertEqual(after.active.map(\.id), ["sticky"])
    }

    func testExpiringNoopWhenNothingExpired() {
        let s = Logic.posting(act("a", expiresAt: 100), into: .empty)
        XCTAssertEqual(Logic.expiring(s, now: 50), s)
    }

    func testExpiringClampsIndex() {
        var s = Logic.posting(act("a", postedAt: 2, expiresAt: nil), into: .empty)
        s = Logic.posting(act("b", postedAt: 1, expiresAt: 5), into: s)
        s = Logic.cycled(s, forward: true)        // focus b (index 1)
        let after = Logic.expiring(s, now: 5)     // b gone → [a], index clamps
        XCTAssertEqual(after.active.map(\.id), ["a"])
        XCTAssertEqual(Logic.frontmost(after)?.id, "a")
    }

    // MARK: frontmost / value clamping

    func testFrontmostNilOnEmpty() {
        XCTAssertNil(Logic.frontmost(.empty))
    }

    func testActivityClampsProgress() {
        XCTAssertEqual(Activity(id: "x", kind: .download, title: "x", progress: 2).progress, 1)
        XCTAssertEqual(Activity(id: "x", kind: .download, title: "x", progress: -1).progress, 0)
        XCTAssertNil(Activity(id: "x", kind: .timer, title: "x").progress)
    }
}
