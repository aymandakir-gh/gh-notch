import AppKit
import Observation

/// Observable state for the notch panel.
///
/// Owns the collapse/expand state and the most recently sampled geometry. The
/// panel reads `currentFrame` to size/position its window; the SwiftUI view reads
/// `isExpanded` to choose its layout.
@Observable
final class NotchViewModel {

    /// Whether the panel is showing its expanded surface (true) or the collapsed
    /// strip that hugs the notch (false).
    var isExpanded: Bool = false

    /// The latest geometry sampled from the active screen. `nil` before the first
    /// sample (e.g. headless boot); the panel skips positioning until it is set.
    private(set) var geometry: NotchGeometry?

    /// User override for notch width (Settings, future slice). When non-nil it
    /// replaces the sampled width. Stubbed now; no UI yet.
    var notchWidthOverride: CGFloat?

    /// Size of the expanded surface. Tight to the command bar + clock/battery row
    /// so there is no empty black void.
    let expandedSize = NSSize(width: 360, height: 150)

    /// Height of the always-visible status strip revealed just below the physical
    /// notch while collapsed (shows time + battery, and is the click target).
    let collapsedReveal: CGFloat = 22

    /// Invoked after any state change that alters `currentFrame` (expand/collapse).
    /// The panel sets this to reposition/resize its window. Not part of observable
    /// state — it is an imperative side-effect hook, kept out of `@ObservationIgnored`
    /// reads by being a plain stored closure the panel owns.
    @ObservationIgnored var onLayoutChange: (() -> Void)?

    /// Update the stored geometry from a fresh sample.
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

    /// The frame the panel window should occupy right now, in AppKit screen
    /// coordinates. Returns `nil` until geometry has been sampled at least once.
    var currentFrame: NSRect? {
        guard let geometry else { return nil }
        let notchHeight = geometry.notchHeight
        let collapsed = collapsedFrame(from: geometry)
        guard isExpanded else { return collapsed }

        // Expanded surface drops down from under the notch, centered on it.
        let width = max(expandedSize.width, collapsed.width)
        let height = notchHeight + expandedSize.height
        let originX = collapsed.midX - (width / 2)
        let originY = collapsed.maxY - height
        return NSRect(x: originX, y: originY, width: width, height: height)
    }

    /// Collapsed frame: the notch height plus a small revealed strip below it,
    /// with the user width override applied if set.
    private func collapsedFrame(from geometry: NotchGeometry) -> NSRect {
        let notch = geometry.collapsedFrame
        let width: CGFloat
        if let override = notchWidthOverride, override > 0 {
            width = override
        } else {
            width = notch.width
        }
        let height = notch.height + collapsedReveal
        let originX = notch.midX - (width / 2)
        let originY = notch.maxY - height
        return NSRect(x: originX, y: originY, width: width, height: height)
    }
}
