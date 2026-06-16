import AppKit
import Observation

/// Observable state for the notch panel.
///
/// Owns the collapse/expand state and the most recently sampled geometry. The
/// panel reads `currentFrame` to size/position its window; the SwiftUI view reads
/// `isExpanded` to choose its layout.
@Observable
final class NotchViewModel {

    /// Whether the panel is showing its expanded dropdown (true) or the collapsed
    /// status bar that flanks the notch (false).
    var isExpanded: Bool = false

    /// The latest geometry sampled from the active screen. `nil` before the first
    /// sample (e.g. headless boot); the panel skips positioning until it is set.
    private(set) var geometry: NotchGeometry?

    /// User override for notch width (Settings, future slice). When non-nil it
    /// replaces the sampled width. Stubbed now; no UI yet.
    var notchWidthOverride: CGFloat?

    /// Size of the expanded dropdown surface (below the notch). Sized for the worst
    /// case — command bar with a two-line result + a full Today agenda + the status
    /// row — so nothing clips; sparser states just leave whitespace.
    let expandedSize = NSSize(width: 380, height: 300)

    /// Width of each status section flanking the notch when collapsed. The left
    /// flank holds the time plus the optional next-event chip, so this is sized for
    /// both; the content hugs the notch edge and the empty remainder is
    /// hit-test-transparent (click-through), so the wider footprint is harmless.
    let sideWidth: CGFloat = 124

    /// While true, a mouse-exit will not auto-collapse — the command bar is in use.
    /// The view keeps this in sync with the command bar state.
    @ObservationIgnored var pinnedOpen = false

    /// Invoked after any state change that alters `currentFrame` (expand/collapse).
    @ObservationIgnored var onLayoutChange: (() -> Void)?

    func update(geometry: NotchGeometry) {
        self.geometry = geometry
    }

    func toggle() {
        isExpanded.toggle()
        onLayoutChange?()
    }

    func collapse() {
        guard isExpanded else { return }
        isExpanded = false
        onLayoutChange?()
    }

    func expand() {
        guard !isExpanded else { return }
        isExpanded = true
        onLayoutChange?()
    }

    /// Collapse because the pointer left the panel — unless pinned open.
    func collapseOnMouseExit() {
        guard !pinnedOpen else { return }
        collapse()
    }

    /// Notch width (user override, else sampled).
    var collapsedNotchWidth: CGFloat {
        guard let geometry else { return NotchGeometry.fallbackWidth }
        if let override = notchWidthOverride, override > 0 { return override }
        return geometry.collapsedFrame.width
    }

    /// Notch / menu-bar height.
    var collapsedNotchHeight: CGFloat {
        geometry?.notchHeight ?? NotchGeometry.fallbackHeight
    }

    /// The frame the panel window should occupy right now, in AppKit screen
    /// coordinates. Returns `nil` until geometry has been sampled at least once.
    var currentFrame: NSRect? {
        guard let geometry else { return nil }
        let notch = geometry.collapsedFrame
        let notchWidth = collapsedNotchWidth

        if !isExpanded {
            // Collapsed: a thin bar at menu-bar level spanning the notch plus a
            // status section on each side.
            let width = notchWidth + 2 * sideWidth
            let height = notch.height
            return NSRect(x: notch.midX - width / 2, y: notch.maxY - height, width: width, height: height)
        }

        // Expanded: a centered dropdown below the notch.
        let width = max(expandedSize.width, notchWidth)
        let height = notch.height + expandedSize.height
        return NSRect(x: notch.midX - width / 2, y: notch.maxY - height, width: width, height: height)
    }
}
