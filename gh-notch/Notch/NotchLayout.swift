import CoreGraphics
import Foundation

/// Pure layout math for the morphing panel (docs/PARITY-ROADMAP.md §2.2–2.3).
///
/// Two coordinate spaces:
/// - `panelFrame(...)` is in AppKit screen coordinates (origin bottom-left): the
///   ONE pre-sized window envelope. The panel window is set to this frame once
///   per screen change and never resized on expand/collapse — the morph happens
///   entirely in SwiftUI inside it.
/// - `islandSize(...)` is a plain size: the visible black island the SwiftUI
///   layer draws top-center inside the panel, per state. Springs animate between
///   these sizes.
///
/// Replaces `NotchViewModel.currentFrame`'s fixed `expandedSize = 380×410`:
/// expanded height is now measured content, capped at a fraction of the screen.
struct NotchLayout: Equatable {

    struct Metrics: Equatable {
        /// Width of each interactive status flank beside the notch (collapsed).
        var sideWidth: CGFloat = 124
        /// Minimum width of the expanded surface (grows to fit wide notches).
        var expandedWidth: CGFloat = 380
        /// Expanded content height cap, as a fraction of the screen height.
        var expandedHeightFraction: CGFloat = 0.6
        /// Extra island width on EACH side of the notch for peek/hud/activity.
        var transientWingWidth: CGFloat = 88
        /// How far a transient island dips below the notch bottom edge.
        var transientExtraHeight: CGFloat = 8

        static let standard = Metrics()
    }

    let geometry: NotchGeometry
    /// Frame of the screen hosting this panel (AppKit coordinates).
    let screenFrame: CGRect
    let metrics: Metrics

    init(geometry: NotchGeometry, screenFrame: CGRect, metrics: Metrics = .standard) {
        self.geometry = geometry
        self.screenFrame = screenFrame
        self.metrics = metrics
    }

    /// Notch width honoring the user override (Settings), else the sampled one.
    func notchWidth(override: CGFloat? = nil) -> CGFloat {
        if let override, override > 0 { return override }
        return geometry.collapsedFrame.width
    }

    /// Upper bound for the expanded surface's content height.
    var maxExpandedContentHeight: CGFloat {
        (screenFrame.height * metrics.expandedHeightFraction).rounded(.down)
    }

    /// The collapsed interactive strip's width (flank + notch + flank). The
    /// island itself is only the notch part; the flanks carry time/battery and
    /// stay click-through where empty.
    func collapsedStripWidth(override: CGFloat? = nil) -> CGFloat {
        notchWidth(override: override) + 2 * metrics.sideWidth
    }

    /// The one pre-sized window envelope, in screen coordinates. Wide enough for
    /// the collapsed strip AND the expanded surface; tall enough for the notch
    /// plus the expanded content cap. Anchored to the top of the screen,
    /// horizontally centered on the notch.
    func panelFrame(override: CGFloat? = nil) -> CGRect {
        let notch = geometry.collapsedFrame
        let width = max(collapsedStripWidth(override: override),
                        max(metrics.expandedWidth, notchWidth(override: override)))
        let height = geometry.notchHeight + maxExpandedContentHeight
        return CGRect(
            x: notch.midX - width / 2,
            y: notch.maxY - height,
            width: width,
            height: height
        )
    }

    /// Size of the drawn island for a state. `contentHeight` is the measured
    /// expanded content height (ignored for other states).
    func islandSize(
        for state: NotchState,
        override: CGFloat? = nil,
        contentHeight: CGFloat = 0
    ) -> CGSize {
        let notchWidth = notchWidth(override: override)
        let panelWidth = panelFrame(override: override).width

        switch state {
        case .collapsed:
            return CGSize(width: notchWidth, height: geometry.notchHeight)
        case .peek, .hud, .activity:
            let width = min(notchWidth + 2 * metrics.transientWingWidth, panelWidth)
            return CGSize(width: width,
                          height: geometry.notchHeight + metrics.transientExtraHeight)
        case .expanded:
            let width = min(max(metrics.expandedWidth, notchWidth), panelWidth)
            let clamped = min(max(contentHeight, 0), maxExpandedContentHeight)
            return CGSize(width: width, height: geometry.notchHeight + clamped)
        }
    }
}
