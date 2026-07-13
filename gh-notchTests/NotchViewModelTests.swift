import XCTest
@testable import gh_notch

@MainActor
final class NotchViewModelTests: XCTestCase {

    /// Short transient durations so async timer tests stay fast but keep
    /// generous margins against slow CI runners.
    private func makeViewModel() -> NotchViewModel {
        NotchViewModel(durations: TransientDurations(peek: 0.3, hud: 0.3, activity: 0.3))
    }

    private func sleep(_ seconds: TimeInterval) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    // MARK: - Basics

    func testStartsCollapsed() {
        XCTAssertEqual(makeViewModel().state, .collapsed)
        XCTAssertFalse(makeViewModel().isExpanded)
    }

    func testTapExpandsAndEscapeCollapses() {
        let viewModel = makeViewModel()
        viewModel.handle(.tap)
        XCTAssertTrue(viewModel.isExpanded)
        viewModel.handle(.escape)
        XCTAssertEqual(viewModel.state, .collapsed)
    }

    func testStateChangeCallbackFiresOnlyOnRealChanges() {
        let viewModel = makeViewModel()
        var changes: [NotchState] = []
        viewModel.onStateChange = { changes.append($0) }

        viewModel.handle(.tap)          // collapsed -> expanded
        viewModel.handle(.tap)          // no-op
        viewModel.handle(.hoverEnter)   // no-op
        viewModel.handle(.escape)       // expanded -> collapsed
        viewModel.handle(.escape)       // no-op

        XCTAssertEqual(changes, [.expanded, .collapsed])
    }

    // MARK: - Pinning

    func testPinBlocksHoverExitAndClickAwayUntilCleared() {
        let viewModel = makeViewModel()
        viewModel.handle(.tap)
        viewModel.setPin(.commandBar, true)

        viewModel.handle(.hoverExit)
        XCTAssertTrue(viewModel.isExpanded)
        viewModel.handle(.clickAway)
        XCTAssertTrue(viewModel.isExpanded)

        viewModel.setPin(.commandBar, false)
        viewModel.handle(.hoverExit)
        XCTAssertEqual(viewModel.state, .collapsed)
    }

    func testPinnedWhileAnyReasonRemains() {
        let viewModel = makeViewModel()
        viewModel.setPin(.commandBar, true)
        viewModel.setPin(.shelfDrag, true)
        viewModel.setPin(.commandBar, false)
        XCTAssertTrue(viewModel.pinned)
        viewModel.setPin(.shelfDrag, false)
        XCTAssertFalse(viewModel.pinned)
    }

    func testEscapeCollapsesEvenWhenPinned() {
        let viewModel = makeViewModel()
        viewModel.handle(.tap)
        viewModel.setPin(.permissionDialog, true)
        viewModel.handle(.escape)
        XCTAssertEqual(viewModel.state, .collapsed)
    }

    // MARK: - Auto-dismiss clock

    func testTransientSchedulesDismissAndCollapsesAfterDuration() async {
        let viewModel = makeViewModel()
        viewModel.handle(.hudEvent(.volume))
        XCTAssertEqual(viewModel.state, .hud(.volume))
        XCTAssertTrue(viewModel.hasPendingAutoDismiss)

        await sleep(0.6) // duration 0.3 + margin
        XCTAssertEqual(viewModel.state, .collapsed)
        XCTAssertFalse(viewModel.hasPendingAutoDismiss)
    }

    func testExpandingCancelsThePendingDismiss() async {
        let viewModel = makeViewModel()
        viewModel.handle(.hudEvent(.volume))
        viewModel.handle(.tap)
        XCTAssertTrue(viewModel.isExpanded)
        XCTAssertFalse(viewModel.hasPendingAutoDismiss)

        await sleep(0.6)
        XCTAssertTrue(viewModel.isExpanded, "a cancelled hud timer must never collapse the panel")
    }

    func testReplacingTransientRestartsTheClock() async {
        let viewModel = makeViewModel()
        viewModel.handle(.hudEvent(.volume))
        await sleep(0.2)                     // 0.2 of 0.3 elapsed
        viewModel.handle(.hudEvent(.brightness)) // restart
        await sleep(0.2)                     // 0.4 since first post, 0.2 since restart
        XCTAssertEqual(viewModel.state, .hud(.brightness), "restarted timer must not fire on the old deadline")
        await sleep(0.4)
        XCTAssertEqual(viewModel.state, .collapsed)
    }

    // MARK: - Geometry + interactive rects

    private let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)

    private func applyTestGeometry(_ viewModel: NotchViewModel) {
        let geometry = NotchGeometry(
            hasNotch: true,
            collapsedFrame: CGRect(x: (1512 - 200) / 2, y: 982 - 32, width: 200, height: 32),
            notchHeight: 32
        )
        viewModel.update(geometry: geometry, screenFrame: screen)
    }

    func testGeometryUpdateFiresCallbackAndBuildsLayout() {
        let viewModel = makeViewModel()
        var fired = 0
        viewModel.onGeometryChange = { fired += 1 }
        XCTAssertNil(viewModel.layout)

        applyTestGeometry(viewModel)
        XCTAssertEqual(fired, 1)
        XCTAssertNotNil(viewModel.layout)
        XCTAssertEqual(viewModel.collapsedNotchWidth, 200)
        XCTAssertEqual(viewModel.collapsedNotchHeight, 32)
    }

    func testInteractiveRectsCoverStripWhenCollapsedAndIslandWhenExpanded() throws {
        let viewModel = makeViewModel()
        XCTAssertEqual(viewModel.interactiveRects(), []) // no geometry yet: pass-through

        applyTestGeometry(viewModel)
        let layout = try XCTUnwrap(viewModel.layout)
        let panel = layout.panelFrame()

        let collapsedRect = try XCTUnwrap(viewModel.interactiveRects().first)
        XCTAssertEqual(collapsedRect.width, layout.collapsedStripWidth(), accuracy: 1)
        XCTAssertEqual(collapsedRect.height, 32, accuracy: 0.5)
        XCTAssertEqual(collapsedRect.maxY, panel.height, accuracy: 0.5) // hugs the top

        viewModel.handle(.tap)
        viewModel.expandedContentHeight = 300
        let expandedRect = try XCTUnwrap(viewModel.interactiveRects().first)
        XCTAssertEqual(expandedRect.width, layout.metrics.expandedWidth, accuracy: 1)
        XCTAssertEqual(expandedRect.height, 32 + 300, accuracy: 0.5)
        XCTAssertEqual(expandedRect.maxY, panel.height, accuracy: 0.5)
        XCTAssertEqual(expandedRect.midX, panel.width / 2, accuracy: 1) // centered
    }

    func testIslandSizeUsesMeasuredContentHeight() {
        let viewModel = makeViewModel()
        applyTestGeometry(viewModel)
        viewModel.expandedContentHeight = 250
        XCTAssertEqual(viewModel.islandSize(for: .expanded).height, 32 + 250)
    }
}
