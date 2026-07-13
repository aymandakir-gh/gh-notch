import XCTest
@testable import gh_notch

final class NotchStateMachineTests: XCTestCase {

    private let durations = TransientDurations.standard
    private let peekA = PeekContent(id: "track-a")
    private let peekB = PeekContent(id: "track-b")
    private let actA = ActivityID(raw: "timer-1")
    private let actB = ActivityID(raw: "download-2")

    private func next(
        _ state: NotchState, _ event: NotchEvent, pinned: Bool = false
    ) -> NotchTransition {
        NotchStateMachine.transition(from: state, on: event, pinned: pinned, durations: durations)
    }

    // MARK: - Opening

    func testHoverEnterExpandsFromCollapsedPeekActivity() {
        XCTAssertEqual(next(.collapsed, .hoverEnter).next, .expanded)
        XCTAssertEqual(next(.peek(peekA), .hoverEnter).next, .expanded)
        XCTAssertEqual(next(.activity(actA), .hoverEnter).next, .expanded)
    }

    func testHoverEnterDoesNotInterruptHudOrExpanded() {
        XCTAssertEqual(next(.hud(.volume), .hoverEnter).next, .hud(.volume))
        XCTAssertEqual(next(.expanded, .hoverEnter).next, .expanded)
    }

    func testTapExpandsFromEveryNonExpandedState() {
        XCTAssertEqual(next(.collapsed, .tap).next, .expanded)
        XCTAssertEqual(next(.peek(peekA), .tap).next, .expanded)
        XCTAssertEqual(next(.hud(.brightness), .tap).next, .expanded)
        XCTAssertEqual(next(.activity(actA), .tap).next, .expanded)
        XCTAssertEqual(next(.expanded, .tap).next, .expanded)
    }

    func testEnteringExpandedNeverSchedulesAutoDismiss() {
        XCTAssertNil(next(.collapsed, .tap).autoDismissAfter)
        XCTAssertNil(next(.peek(peekA), .hoverEnter).autoDismissAfter)
        XCTAssertNil(next(.activity(actA), .swipe(.down)).autoDismissAfter)
    }

    // MARK: - Transient priority (hud > activity > peek)

    func testHudReplacesPeekAndActivityAndItself() {
        XCTAssertEqual(next(.peek(peekA), .hudEvent(.volume)).next, .hud(.volume))
        XCTAssertEqual(next(.activity(actA), .hudEvent(.volume)).next, .hud(.volume))
        XCTAssertEqual(next(.hud(.volume), .hudEvent(.brightness)).next, .hud(.brightness))
    }

    func testHudNeverInterruptsExpanded() {
        XCTAssertEqual(next(.expanded, .hudEvent(.volume)).next, .expanded)
        XCTAssertNil(next(.expanded, .hudEvent(.volume)).autoDismissAfter)
    }

    func testHudRestartsItsTimerOnEveryHudEvent() {
        XCTAssertEqual(next(.collapsed, .hudEvent(.volume)).autoDismissAfter, durations.hud)
        XCTAssertEqual(next(.hud(.volume), .hudEvent(.volume)).autoDismissAfter, durations.hud)
    }

    func testActivityReplacesPeekAndActivityButLosesToHud() {
        XCTAssertEqual(next(.peek(peekA), .activityPosted(actA)).next, .activity(actA))
        XCTAssertEqual(next(.activity(actA), .activityPosted(actB)).next, .activity(actB))
        XCTAssertEqual(next(.hud(.volume), .activityPosted(actA)).next, .hud(.volume))
        XCTAssertEqual(next(.expanded, .activityPosted(actA)).next, .expanded)
    }

    func testPeekOnlyShowsOverCollapsedOrPeek() {
        XCTAssertEqual(next(.collapsed, .peekPosted(peekA)).next, .peek(peekA))
        XCTAssertEqual(next(.peek(peekA), .peekPosted(peekB)).next, .peek(peekB))
        XCTAssertEqual(next(.activity(actA), .peekPosted(peekA)).next, .activity(actA))
        XCTAssertEqual(next(.hud(.volume), .peekPosted(peekA)).next, .hud(.volume))
        XCTAssertEqual(next(.expanded, .peekPosted(peekA)).next, .expanded)
    }

    func testTransientArrivalSchedulesItsConfiguredDuration() {
        XCTAssertEqual(next(.collapsed, .peekPosted(peekA)).autoDismissAfter, durations.peek)
        XCTAssertEqual(next(.collapsed, .hudEvent(.volume)).autoDismissAfter, durations.hud)
        XCTAssertEqual(next(.collapsed, .activityPosted(actA)).autoDismissAfter, durations.activity)
    }

    func testIgnoredPostLeavesExistingTimerUntouched() {
        // A losing post must return nil so the current transient's timer keeps running.
        XCTAssertNil(next(.hud(.volume), .activityPosted(actA)).autoDismissAfter)
        XCTAssertNil(next(.activity(actA), .peekPosted(peekA)).autoDismissAfter)
    }

    // MARK: - Timeouts (stale-timer safety)

    func testTimeoutDismissesOnlyItsOwnKind() {
        XCTAssertEqual(next(.peek(peekA), .timeout(.peek)).next, .collapsed)
        XCTAssertEqual(next(.hud(.volume), .timeout(.hud)).next, .collapsed)
        XCTAssertEqual(next(.activity(actA), .timeout(.activity)).next, .collapsed)
    }

    func testStaleTimeoutNeverDismissesADifferentState() {
        XCTAssertEqual(next(.hud(.volume), .timeout(.peek)).next, .hud(.volume))
        XCTAssertEqual(next(.activity(actA), .timeout(.hud)).next, .activity(actA))
        XCTAssertEqual(next(.peek(peekA), .timeout(.activity)).next, .peek(peekA))
        XCTAssertEqual(next(.expanded, .timeout(.peek)).next, .expanded)
        XCTAssertEqual(next(.collapsed, .timeout(.hud)).next, .collapsed)
    }

    // MARK: - Activity dismissal

    func testActivityDismissedCollapsesOnlyOnMatchingID() {
        XCTAssertEqual(next(.activity(actA), .activityDismissed(actA)).next, .collapsed)
        XCTAssertEqual(next(.activity(actA), .activityDismissed(actB)).next, .activity(actA))
        XCTAssertEqual(next(.collapsed, .activityDismissed(actA)).next, .collapsed)
        XCTAssertEqual(next(.expanded, .activityDismissed(actA)).next, .expanded)
    }

    // MARK: - Closing

    func testEscapeAlwaysCollapsesEvenWhenPinned() {
        XCTAssertEqual(next(.expanded, .escape, pinned: true).next, .collapsed)
        XCTAssertEqual(next(.expanded, .escape).next, .collapsed)
        XCTAssertEqual(next(.peek(peekA), .escape).next, .collapsed)
        XCTAssertEqual(next(.hud(.volume), .escape).next, .collapsed)
        XCTAssertEqual(next(.collapsed, .escape).next, .collapsed)
    }

    func testHoverExitCollapsesExpandedUnlessPinned() {
        XCTAssertEqual(next(.expanded, .hoverExit).next, .collapsed)
        XCTAssertEqual(next(.expanded, .hoverExit, pinned: true).next, .expanded)
    }

    func testHoverExitLeavesTransientsAlone() {
        XCTAssertEqual(next(.peek(peekA), .hoverExit).next, .peek(peekA))
        XCTAssertEqual(next(.hud(.volume), .hoverExit).next, .hud(.volume))
        XCTAssertEqual(next(.activity(actA), .hoverExit).next, .activity(actA))
        // And their running timers stay untouched.
        XCTAssertNil(next(.peek(peekA), .hoverExit).autoDismissAfter)
    }

    func testClickAwayCollapsesExpandedUnlessPinned() {
        XCTAssertEqual(next(.expanded, .clickAway).next, .collapsed)
        // The v0.2 permission-dialog bug: clicking the system dialog must NOT
        // collapse the panel while pinned.
        XCTAssertEqual(next(.expanded, .clickAway, pinned: true).next, .expanded)
    }

    // MARK: - Swipes

    func testSwipeDownExpands() {
        XCTAssertEqual(next(.collapsed, .swipe(.down)).next, .expanded)
        XCTAssertEqual(next(.peek(peekA), .swipe(.down)).next, .expanded)
        XCTAssertEqual(next(.hud(.volume), .swipe(.down)).next, .expanded)
        XCTAssertEqual(next(.activity(actA), .swipe(.down)).next, .expanded)
        XCTAssertEqual(next(.expanded, .swipe(.down)).next, .expanded)
    }

    func testSwipeUpDismissesAndCollapses() {
        XCTAssertEqual(next(.expanded, .swipe(.up)).next, .collapsed)
        XCTAssertEqual(next(.peek(peekA), .swipe(.up)).next, .collapsed)
        XCTAssertEqual(next(.hud(.volume), .swipe(.up)).next, .collapsed)
        XCTAssertEqual(next(.activity(actA), .swipe(.up)).next, .collapsed)
        XCTAssertEqual(next(.collapsed, .swipe(.up)).next, .collapsed)
    }

    func testSwipeUpRespectsPinWhileExpanded() {
        XCTAssertEqual(next(.expanded, .swipe(.up), pinned: true).next, .expanded)
    }

    func testHorizontalSwipesAreReservedNoOps() {
        for state: NotchState in [.collapsed, .peek(peekA), .hud(.volume), .activity(actA), .expanded] {
            XCTAssertEqual(next(state, .swipe(.left)).next, state)
            XCTAssertEqual(next(state, .swipe(.right)).next, state)
        }
    }

    // MARK: - Whole-table sanity

    func testNoTransitionEverSchedulesATimerForANonTransientTarget() {
        let states: [NotchState] = [.collapsed, .peek(peekA), .hud(.volume), .activity(actA), .expanded]
        let events: [NotchEvent] = [
            .hoverEnter, .hoverExit, .tap, .escape, .clickAway,
            .swipe(.up), .swipe(.down), .swipe(.left), .swipe(.right),
            .peekPosted(peekA), .activityPosted(actA), .activityDismissed(actA),
            .hudEvent(.volume), .timeout(.peek), .timeout(.hud), .timeout(.activity)
        ]
        for state in states {
            for event in events {
                for pinned in [false, true] {
                    let transition = NotchStateMachine.transition(
                        from: state, on: event, pinned: pinned, durations: durations
                    )
                    if transition.autoDismissAfter != nil {
                        switch transition.next {
                        case .peek, .hud, .activity:
                            break // legal: timers belong to transients only
                        case .collapsed, .expanded:
                            XCTFail("scheduled a timer for \(transition.next) on \(state) + \(event)")
                        }
                    }
                }
            }
        }
    }
}
