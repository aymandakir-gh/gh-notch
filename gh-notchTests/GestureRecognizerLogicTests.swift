import XCTest
@testable import gh_notch

final class GestureRecognizerLogicTests: XCTestCase {

    private var recognizer = GestureRecognizerLogic()
    private var clock: TimeInterval = 100.0

    override func setUp() {
        super.setUp()
        recognizer = GestureRecognizerLogic()
        clock = 100.0
    }

    /// Build a trackpad sample 16ms after the previous one.
    private func trackpad(
        _ dx: CGFloat, _ dy: CGFloat,
        phase: ScrollPhase = .changed,
        momentum: ScrollPhase = ScrollPhase.none
    ) -> ScrollSample {
        clock += 0.016
        return ScrollSample(
            deltaX: dx, deltaY: dy, phase: phase, momentumPhase: momentum,
            hasPreciseDeltas: true, timestamp: clock
        )
    }

    private func wheel(_ dx: CGFloat, _ dy: CGFloat) -> ScrollSample {
        clock += 0.016
        return ScrollSample(
            deltaX: dx, deltaY: dy, phase: ScrollPhase.none, momentumPhase: ScrollPhase.none,
            hasPreciseDeltas: false, timestamp: clock
        )
    }

    // MARK: - Basic commits

    func testDownSwipeCommitsOnceAfterThreshold() {
        XCTAssertNil(recognizer.consume(trackpad(0, 0, phase: .began)))
        XCTAssertNil(recognizer.consume(trackpad(0, 1.5)))
        XCTAssertNil(recognizer.consume(trackpad(0, 1.5)))
        XCTAssertEqual(recognizer.consume(trackpad(0, 1.5)), .down) // 4.5 ≥ 4
        // Further finger movement must not re-fire.
        XCTAssertNil(recognizer.consume(trackpad(0, 5)))
        XCTAssertNil(recognizer.consume(trackpad(0, 5)))
        XCTAssertEqual(recognizer.phase, .draining)
    }

    func testUpAndHorizontalDirections() {
        XCTAssertNil(recognizer.consume(trackpad(0, 0, phase: .began)))
        XCTAssertEqual(recognizer.consume(trackpad(0, -5)), .up)

        var horizontal = GestureRecognizerLogic()
        XCTAssertNil(horizontal.consume(trackpad(0, 0, phase: .began)))
        XCTAssertEqual(horizontal.consume(trackpad(6, 0)), .right)

        var left = GestureRecognizerLogic()
        XCTAssertNil(left.consume(trackpad(0, 0, phase: .began)))
        XCTAssertEqual(left.consume(trackpad(-6, 0)), .left)
    }

    // MARK: - The momentum re-trigger gotcha

    func testMomentumTailAfterCommitNeverRefires() {
        XCTAssertNil(recognizer.consume(trackpad(0, 0, phase: .began)))
        XCTAssertEqual(recognizer.consume(trackpad(0, 6)), .down)
        XCTAssertNil(recognizer.consume(trackpad(0, 2, phase: .ended)))
        // Momentum keeps delivering big deltas — all swallowed.
        XCTAssertNil(recognizer.consume(trackpad(0, 8, momentum: .began)))
        XCTAssertNil(recognizer.consume(trackpad(0, 8, momentum: .changed)))
        XCTAssertNil(recognizer.consume(trackpad(0, 8, momentum: .changed)))
        XCTAssertNil(recognizer.consume(trackpad(0, 0, momentum: .ended)))
        XCTAssertEqual(recognizer.phase, .idle)
        // A genuinely new gesture fires again.
        XCTAssertNil(recognizer.consume(trackpad(0, 0, phase: .began)))
        XCTAssertEqual(recognizer.consume(trackpad(0, 6)), .down)
    }

    func testFreshFingersMidDrainStartANewGesture() {
        XCTAssertNil(recognizer.consume(trackpad(0, 0, phase: .began)))
        XCTAssertEqual(recognizer.consume(trackpad(0, 6)), .down)
        XCTAssertNil(recognizer.consume(trackpad(0, 3, momentum: .began)))
        // User plants fingers again while momentum is still draining.
        XCTAssertNil(recognizer.consume(trackpad(0, 0, phase: .began)))
        XCTAssertEqual(recognizer.consume(trackpad(0, -6)), .up)
    }

    // MARK: - Non-commits

    func testEndedWithoutThresholdResets() {
        XCTAssertNil(recognizer.consume(trackpad(0, 0, phase: .began)))
        XCTAssertNil(recognizer.consume(trackpad(0, 1)))
        XCTAssertNil(recognizer.consume(trackpad(0, 0, phase: .ended)))
        XCTAssertEqual(recognizer.phase, .idle)
        // Accumulation must not leak into the next gesture.
        XCTAssertNil(recognizer.consume(trackpad(0, 0, phase: .began)))
        XCTAssertNil(recognizer.consume(trackpad(0, 3)))
        XCTAssertEqual(recognizer.phase, .tracking)
    }

    func testCancelledResets() {
        XCTAssertNil(recognizer.consume(trackpad(0, 0, phase: .began)))
        XCTAssertNil(recognizer.consume(trackpad(0, 3)))
        XCTAssertNil(recognizer.consume(trackpad(0, 0, phase: .cancelled)))
        XCTAssertEqual(recognizer.phase, .idle)
    }

    func testNoiseFloorIgnoresMicroDeltas() {
        XCTAssertNil(recognizer.consume(trackpad(0, 0, phase: .began)))
        for _ in 0..<100 {
            XCTAssertNil(recognizer.consume(trackpad(0.1, 0.1)))
        }
        XCTAssertEqual(recognizer.phase, .tracking) // still nothing accumulated
    }

    func testDiagonalWithoutDominanceDoesNotCommit() {
        XCTAssertNil(recognizer.consume(trackpad(0, 0, phase: .began)))
        // 5 vs 4: above threshold but 5 < 4 × 1.5 — ambiguous, no commit.
        XCTAssertNil(recognizer.consume(trackpad(4, 5)))
        // Vertical pulls decisively ahead: 10 ≥ 4 and 10 ≥ 4 × 1.5.
        XCTAssertEqual(recognizer.consume(trackpad(0, 5)), .down)
    }

    // MARK: - Mouse wheel (no phases, imprecise deltas)

    func testMouseWheelAmplificationCommits() {
        // 0.6 × 8 = 4.8 ≥ threshold in a single tick, no began phase needed.
        XCTAssertEqual(recognizer.consume(wheel(0, 0.6)), .down)
        // The burst keeps scrolling — swallowed by draining.
        XCTAssertNil(recognizer.consume(wheel(0, 0.6)))
        XCTAssertNil(recognizer.consume(wheel(0, 0.6)))
    }

    func testSilenceResetEndsDrainingAndAllowsANewWheelSwipe() {
        XCTAssertEqual(recognizer.consume(wheel(0, 0.6)), .down)
        XCTAssertEqual(recognizer.phase, .draining)
        clock += 1.0 // a quiet second passes
        XCTAssertEqual(recognizer.consume(wheel(0, 0.6)), .down)
    }

    func testStrayMomentumWhileIdleIsIgnored() {
        XCTAssertNil(recognizer.consume(trackpad(0, 9, momentum: .changed)))
        XCTAssertEqual(recognizer.phase, .idle)
    }
}
