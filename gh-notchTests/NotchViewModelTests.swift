import XCTest
@testable import gh_notch

final class NotchViewModelTests: XCTestCase {

    func testStartsCollapsed() {
        let viewModel = NotchViewModel()
        XCTAssertFalse(viewModel.isExpanded)
    }

    func testToggleFlipsStateAndFiresLayoutChange() {
        let viewModel = NotchViewModel()
        var layoutChangeCount = 0
        viewModel.onLayoutChange = { layoutChangeCount += 1 }

        viewModel.toggle()
        XCTAssertTrue(viewModel.isExpanded)
        XCTAssertEqual(layoutChangeCount, 1)

        viewModel.toggle()
        XCTAssertFalse(viewModel.isExpanded)
        XCTAssertEqual(layoutChangeCount, 2)
    }

    func testExpandAndCollapseAreIdempotent() {
        let viewModel = NotchViewModel()
        var layoutChangeCount = 0
        viewModel.onLayoutChange = { layoutChangeCount += 1 }

        viewModel.expand()
        viewModel.expand() // no-op, already expanded
        XCTAssertTrue(viewModel.isExpanded)
        XCTAssertEqual(layoutChangeCount, 1)

        viewModel.collapse()
        viewModel.collapse() // no-op, already collapsed
        XCTAssertFalse(viewModel.isExpanded)
        XCTAssertEqual(layoutChangeCount, 2)
    }

    func testCurrentFrameIsNilWithoutGeometry() {
        let viewModel = NotchViewModel()
        XCTAssertNil(viewModel.currentFrame)
    }

    func testCollapsedFrameMatchesGeometry() {
        let viewModel = NotchViewModel()
        let collapsed = NSRect(x: 800, y: 1060, width: 200, height: 32)
        let geometry = NotchGeometry.stub(collapsedFrame: collapsed, notchHeight: 32, hasNotch: true)
        viewModel.update(geometry: geometry)

        XCTAssertEqual(viewModel.currentFrame, collapsed)
    }

    func testExpandedFrameGrowsDownwardAndStaysTopAligned() {
        let viewModel = NotchViewModel()
        let collapsed = NSRect(x: 800, y: 1060, width: 200, height: 32)
        let geometry = NotchGeometry.stub(collapsedFrame: collapsed, notchHeight: 32, hasNotch: true)
        viewModel.update(geometry: geometry)
        viewModel.expand()

        guard let frame = viewModel.currentFrame else {
            return XCTFail("expected a frame once geometry is set")
        }
        // Top edge unchanged (glued to the notch).
        XCTAssertEqual(frame.maxY, collapsed.maxY, accuracy: 0.001)
        // Centered on the notch.
        XCTAssertEqual(frame.midX, collapsed.midX, accuracy: 0.001)
        // Taller than collapsed.
        XCTAssertGreaterThan(frame.height, collapsed.height)
    }

    func testNotchWidthOverrideIsApplied() {
        let viewModel = NotchViewModel()
        let collapsed = NSRect(x: 800, y: 1060, width: 200, height: 32)
        let geometry = NotchGeometry.stub(collapsedFrame: collapsed, notchHeight: 32, hasNotch: true)
        viewModel.update(geometry: geometry)
        viewModel.notchWidthOverride = 300

        guard let frame = viewModel.currentFrame else {
            return XCTFail("expected a frame once geometry is set")
        }
        XCTAssertEqual(frame.width, 300, accuracy: 0.001)
        XCTAssertEqual(frame.midX, collapsed.midX, accuracy: 0.001)
    }
}

// MARK: - Test helpers

extension NotchGeometry {
    /// Memberwise stub for tests. The production initializer is screen-driven and
    /// cannot run headlessly, so tests construct geometry directly.
    static func stub(collapsedFrame: NSRect, notchHeight: CGFloat, hasNotch: Bool) -> NotchGeometry {
        NotchGeometry(hasNotch: hasNotch, collapsedFrame: collapsedFrame, notchHeight: notchHeight)
    }
}
