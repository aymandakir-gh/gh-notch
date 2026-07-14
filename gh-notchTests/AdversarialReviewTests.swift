import XCTest
@testable import gh_notch

/// Cross-cutting regression tests from the v0.4 slice-G adversarial review:
/// stale timers, momentum re-trigger, click-through geometry, multi-display
/// selection, and section-height overflow. Pure-logic only — CI-runnable.
final class AdversarialReviewTests: XCTestCase {

    private let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)

    private func notchedLayout() -> NotchLayout {
        let geometry = NotchGeometry(
            hasNotch: true,
            collapsedFrame: CGRect(x: (1512 - 200) / 2, y: 982 - 32, width: 200, height: 32),
            notchHeight: 32
        )
        return NotchLayout(geometry: geometry, screenFrame: screen)
    }

    // MARK: - Layout: section height overflow / non-finite geometry

    func testNonFiniteContentHeightIsTreatedAsZero() {
        let layout = notchedLayout()
        let nan = layout.islandSize(for: .expanded, contentHeight: .nan)
        XCTAssertEqual(nan.height, 32, accuracy: 0.5)
        XCTAssertTrue(nan.height.isFinite)

        let infinity = layout.islandSize(for: .expanded, contentHeight: .infinity)
        XCTAssertEqual(infinity.height, 32 + layout.maxExpandedContentHeight, accuracy: 0.5)
    }

    func testAbsurdContentHeightNeverExceedsScreenCap() {
        let layout = notchedLayout()
        let capped = layout.islandSize(for: .expanded, contentHeight: 1_000_000)
        XCTAssertEqual(capped.height, 32 + layout.maxExpandedContentHeight, accuracy: 0.5)
        let panel = layout.panelFrame()
        XCTAssertLessThanOrEqual(capped.height, panel.height + 0.5)
    }

    // MARK: - Click-through: interactive rects stay inside the envelope

    @MainActor
    func testInteractiveRectsNeverExceedPanelEnvelopeWhenContentOverflows() throws {
        let viewModel = NotchViewModel()
        let geometry = NotchGeometry(
            hasNotch: true,
            collapsedFrame: CGRect(x: (1512 - 200) / 2, y: 982 - 32, width: 200, height: 32),
            notchHeight: 32
        )
        viewModel.update(geometry: geometry, screenFrame: screen)
        viewModel.handle(.tap)
        viewModel.expandedContentHeight = 1_000_000

        let layout = try XCTUnwrap(viewModel.layout)
        let panel = layout.panelFrame()
        let rect = try XCTUnwrap(viewModel.interactiveRects().first)
        XCTAssertLessThanOrEqual(rect.width, panel.width + 0.5)
        XCTAssertLessThanOrEqual(rect.height, panel.height + 0.5)
        XCTAssertEqual(rect.maxY, panel.height, accuracy: 0.5)
    }

    @MainActor
    func testNoGeometryMeansNoInteractiveRectsForFullClickThrough() {
        let viewModel = NotchViewModel()
        XCTAssertEqual(viewModel.interactiveRects(), [])
    }

    // MARK: - State machine + view model: stale timers

    func testStaleTimeoutNeverDismissesADifferentTransient() {
        let peek = PeekContent(id: "p")
        let hud = NotchStateMachine.transition(from: .hud(.volume), on: .timeout(.peek))
        XCTAssertEqual(hud.next, .hud(.volume))
        XCTAssertNil(hud.autoDismissAfter)

        let activity = NotchStateMachine.transition(
            from: .activity(ActivityID(raw: "a")), on: .timeout(.hud)
        )
        XCTAssertEqual(activity.next, .activity(ActivityID(raw: "a")))
    }

    @MainActor
    func testStaleTimeoutDoesNotClearActiveTransientDismissClock() async {
        let durations = TransientDurations(peek: 0.3, hud: 0.3, activity: 0.3)
        let viewModel = NotchViewModel(durations: durations)
        viewModel.handle(.hudEvent(.volume))
        XCTAssertTrue(viewModel.hasPendingAutoDismiss)

        // Wrong kind — state machine stays in hud; the live hud timer must survive.
        viewModel.handle(.timeout(.peek))
        XCTAssertEqual(viewModel.state, .hud(.volume))
        XCTAssertTrue(viewModel.hasPendingAutoDismiss)

        try? await Task.sleep(nanoseconds: 600_000_000)
        XCTAssertEqual(viewModel.state, .collapsed)
    }

    // MARK: - Gestures: momentum re-trigger

    func testMomentumSampleWithBeganPhaseDoesNotStartFreshTrackingDuringDrain() {
        var recognizer = GestureRecognizerLogic()
        var clock: TimeInterval = 100

        func sample(
            dx: CGFloat, dy: CGFloat,
            phase: ScrollPhase = .changed,
            momentum: ScrollPhase = .none
        ) -> ScrollSample {
            clock += 0.016
            return ScrollSample(
                deltaX: dx, deltaY: dy, phase: phase, momentumPhase: momentum,
                hasPreciseDeltas: true, timestamp: clock
            )
        }

        XCTAssertNil(recognizer.consume(sample(dx: 0, dy: 0, phase: .began)))
        XCTAssertEqual(recognizer.consume(sample(dx: 0, dy: 6)), .down)
        // Momentum takes priority over `.began` on the same stream — no second commit.
        XCTAssertNil(recognizer.consume(sample(dx: 0, dy: 0, phase: .began, momentum: .changed)))
        XCTAssertNil(recognizer.consume(sample(dx: 0, dy: 8, momentum: .changed)))
        XCTAssertNil(recognizer.consume(sample(dx: 0, dy: 0, momentum: .ended)))
        XCTAssertEqual(recognizer.phase, .idle)
    }

    func testSilenceGapDuringDrainAllowsExactlyOneNewCommit() {
        var recognizer = GestureRecognizerLogic()
        var clock: TimeInterval = 100

        func wheel(_ dy: CGFloat) -> ScrollSample {
            clock += 0.016
            return ScrollSample(
                deltaX: 0, deltaY: dy, phase: .none, momentumPhase: .none,
                hasPreciseDeltas: false, timestamp: clock
            )
        }

        XCTAssertEqual(recognizer.consume(wheel(0.6)), .down)
        clock += 1.0 // exceeds silenceReset
        XCTAssertEqual(recognizer.consume(wheel(0.6)), .down)
    }

    // MARK: - Multi-display selection edge cases

    func testBuiltInOnlyWithMultipleBuiltInsPicksTheFirst() {
        let builtInA = ScreenDescriptor(isBuiltIn: true, hasNotch: true, isMenuBarPrimary: false)
        let builtInB = ScreenDescriptor(isBuiltIn: true, hasNotch: true, isMenuBarPrimary: true)
        XCTAssertEqual(
            DisplaySelection.targetIndices(of: [builtInA, builtInB], mode: .builtInOnly),
            [0]
        )
    }

    func testAllModeWithSingleExternalStillReturnsOnePanel() {
        let external = ScreenDescriptor(isBuiltIn: false, hasNotch: false, isMenuBarPrimary: true)
        XCTAssertEqual(DisplaySelection.targetIndices(of: [external], mode: .all), [0])
    }

    // MARK: - Sections: toggle edge cases

    func testEmptyDisabledRawValuesListShowsAllSections() {
        XCTAssertEqual(
            SectionsLogic.visibleSections(disabled: SectionsLogic.disabledSet(fromRawValues: [])),
            [.commandBar, .calendar, .shelf, .statusRow]
        )
    }

    func testDisablingEveryToggleableSectionStillLeavesSettingsPath() {
        let disabled = Set(ExpandedSection.allCases.filter { !$0.isAlwaysOn })
        XCTAssertEqual(SectionsLogic.visibleSections(disabled: disabled), [.statusRow])
    }
}
