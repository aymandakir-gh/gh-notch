import XCTest
@testable import gh_notch

final class NotchLayoutTests: XCTestCase {

    // MacBook Pro 14" -ish: 1512×982 screen, 200×32 notch centered at the top.
    private let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)

    private func notchedLayout(metrics: NotchLayout.Metrics = .standard) -> NotchLayout {
        let geometry = NotchGeometry(
            hasNotch: true,
            collapsedFrame: CGRect(x: (1512 - 200) / 2, y: 982 - 32, width: 200, height: 32),
            notchHeight: 32
        )
        return NotchLayout(geometry: geometry, screenFrame: screen, metrics: metrics)
    }

    private func pillLayout() -> NotchLayout {
        let width = NotchGeometry.fallbackWidth
        let height = NotchGeometry.fallbackHeight
        let geometry = NotchGeometry(
            hasNotch: false,
            collapsedFrame: CGRect(x: (1512 - width) / 2, y: 982 - height, width: width, height: height),
            notchHeight: height
        )
        return NotchLayout(geometry: geometry, screenFrame: screen)
    }

    // MARK: - Panel envelope

    func testPanelFrameIsCenteredOnTheNotchAndTouchesTheScreenTop() {
        let layout = notchedLayout()
        let panel = layout.panelFrame()
        XCTAssertEqual(panel.midX, layout.geometry.collapsedFrame.midX, accuracy: 0.5)
        XCTAssertEqual(panel.maxY, screen.maxY, accuracy: 0.5)
    }

    func testPanelEnvelopeCoversCollapsedStripAndExpandedSurface() {
        let layout = notchedLayout()
        let panel = layout.panelFrame()
        XCTAssertGreaterThanOrEqual(panel.width, layout.collapsedStripWidth())
        XCTAssertGreaterThanOrEqual(panel.width, layout.metrics.expandedWidth)
        XCTAssertEqual(
            panel.height,
            layout.geometry.notchHeight + layout.maxExpandedContentHeight,
            accuracy: 0.5
        )
    }

    func testPanelFrameHonorsWidthOverride() {
        let layout = notchedLayout()
        let wide = layout.panelFrame(override: 320)
        // 320 + 2×124 = 568 > default envelope (200 + 248 = 448 vs 380 floor).
        XCTAssertEqual(wide.width, 320 + 2 * layout.metrics.sideWidth, accuracy: 0.5)
        XCTAssertEqual(layout.notchWidth(override: 320), 320)
        // Non-positive overrides are ignored.
        XCTAssertEqual(layout.notchWidth(override: 0), 200)
        XCTAssertEqual(layout.notchWidth(override: -10), 200)
    }

    // MARK: - Island sizes per state

    func testCollapsedIslandMatchesTheNotch() {
        let layout = notchedLayout()
        let size = layout.islandSize(for: .collapsed)
        XCTAssertEqual(size.width, 200)
        XCTAssertEqual(size.height, 32)
    }

    func testTransientIslandGrowsWingsAndDipsBelowTheNotch() {
        let layout = notchedLayout()
        for state: NotchState in [
            .peek(PeekContent(id: "p")), .hud(.volume), .activity(ActivityID(raw: "a"))
        ] {
            let size = layout.islandSize(for: state)
            XCTAssertEqual(size.width, 200 + 2 * layout.metrics.transientWingWidth)
            XCTAssertEqual(size.height, 32 + layout.metrics.transientExtraHeight)
        }
    }

    func testExpandedIslandTracksContentHeightUpToTheCap() {
        let layout = notchedLayout()
        let small = layout.islandSize(for: .expanded, contentHeight: 220)
        XCTAssertEqual(small.height, 32 + 220)
        XCTAssertEqual(small.width, layout.metrics.expandedWidth)

        let capped = layout.islandSize(for: .expanded, contentHeight: 10_000)
        XCTAssertEqual(capped.height, 32 + layout.maxExpandedContentHeight)

        let negative = layout.islandSize(for: .expanded, contentHeight: -50)
        XCTAssertEqual(negative.height, 32) // clamped to zero content
    }

    func testExpandedCapIsAFractionOfTheScreenHeight() {
        let layout = notchedLayout()
        XCTAssertEqual(
            layout.maxExpandedContentHeight,
            (screen.height * layout.metrics.expandedHeightFraction).rounded(.down)
        )
    }

    func testIslandNeverExceedsThePanelEnvelope() {
        let layout = notchedLayout()
        let panel = layout.panelFrame()
        for state: NotchState in [
            .collapsed, .peek(PeekContent(id: "p")), .hud(.volume),
            .activity(ActivityID(raw: "a")), .expanded
        ] {
            let size = layout.islandSize(for: state, contentHeight: 10_000)
            XCTAssertLessThanOrEqual(size.width, panel.width + 0.5)
            XCTAssertLessThanOrEqual(size.height, panel.height + 0.5)
        }
    }

    func testIslandWidthIsMonotonicCollapsedToTransientToExpanded() {
        let layout = notchedLayout()
        let collapsed = layout.islandSize(for: .collapsed).width
        let transient = layout.islandSize(for: .hud(.volume)).width
        let expanded = layout.islandSize(for: .expanded, contentHeight: 300).width
        XCTAssertLessThan(collapsed, transient)
        XCTAssertLessThanOrEqual(transient, expanded)
    }

    // MARK: - No-notch pill

    func testPillModeUsesFallbackGeometry() {
        let layout = pillLayout()
        let collapsed = layout.islandSize(for: .collapsed)
        XCTAssertEqual(collapsed.width, NotchGeometry.fallbackWidth)
        XCTAssertEqual(collapsed.height, NotchGeometry.fallbackHeight)
        // The envelope still centers and hugs the top.
        let panel = layout.panelFrame()
        XCTAssertEqual(panel.midX, screen.midX, accuracy: 0.5)
        XCTAssertEqual(panel.maxY, screen.maxY, accuracy: 0.5)
    }

    // MARK: - Wide-notch edge case

    func testWiderNotchThanExpandedSurfaceWidensTheExpandedIsland() {
        let geometry = NotchGeometry(
            hasNotch: true,
            collapsedFrame: CGRect(x: 500, y: 950, width: 420, height: 32),
            notchHeight: 32
        )
        let layout = NotchLayout(geometry: geometry, screenFrame: screen)
        let expanded = layout.islandSize(for: .expanded, contentHeight: 200)
        XCTAssertEqual(expanded.width, 420) // grows past the 380 floor
    }
}
