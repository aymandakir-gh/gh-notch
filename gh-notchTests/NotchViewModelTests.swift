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

    func testCollapsedFrameFlanksTheNotch() {
        let viewModel = NotchViewModel()
        let notch = NSRect(x: 800, y: 1060, width: 200, height: 32)
        let geometry = NotchGeometry.stub(collapsedFrame: notch, notchHeight: 32, hasNotch: true)
        viewModel.update(geometry: geometry)

        // Collapsed spans the notch plus a status section on each side, at the
        // menu-bar level (same height as the notch), centered on the notch.
        let expectedWidth = notch.width + 2 * viewModel.sideWidth
        let expected = NSRect(
            x: notch.midX - expectedWidth / 2,
            y: notch.maxY - notch.height,
            width: expectedWidth,
            height: notch.height
        )
        XCTAssertEqual(viewModel.currentFrame, expected)
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
        // Taller than the notch.
        XCTAssertGreaterThan(frame.height, collapsed.height)
    }

    func testNotchWidthOverrideWidensTheCollapsedBar() {
        let viewModel = NotchViewModel()
        let collapsed = NSRect(x: 800, y: 1060, width: 200, height: 32)
        let geometry = NotchGeometry.stub(collapsedFrame: collapsed, notchHeight: 32, hasNotch: true)
        viewModel.update(geometry: geometry)
        viewModel.notchWidthOverride = 300

        guard let frame = viewModel.currentFrame else {
            return XCTFail("expected a frame once geometry is set")
        }
        XCTAssertEqual(frame.width, 300 + 2 * viewModel.sideWidth, accuracy: 0.001)
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
