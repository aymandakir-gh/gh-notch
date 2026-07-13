import AppKit

/// Runtime description of a display's notch (or lack of one).
///
/// All values are sampled from `NSScreen` at runtime — never hardcoded per model,
/// per ARCHITECTURE.md. On non-notched displays `hasNotch` is `false` and the
/// caller falls back to a floating top-center bar.
struct NotchGeometry: Equatable {

    /// Whether the active screen physically has a notch.
    let hasNotch: Bool

    /// The notch bounds in screen coordinates (origin bottom-left, AppKit style),
    /// i.e. the rectangle the panel should occupy when collapsed. On non-notched
    /// displays this is a synthesized top-center rectangle of `fallbackWidth`.
    let collapsedFrame: NSRect

    /// Height of the menu-bar / notch region for the active screen.
    let notchHeight: CGFloat

    // MARK: - Tunables

    /// Width used for the collapsed pill when the display has no notch, or when
    /// the notch width cannot be derived from `safeAreaInsets`. 185pt matches
    /// the field-verified default other notch apps converged on for the
    /// drawn pill (docs/PARITY-ROADMAP.md §2.5).
    static let fallbackWidth: CGFloat = 185

    /// Default collapsed height when `safeAreaInsets.top` is zero (non-notched).
    static let fallbackHeight: CGFloat = 32

    /// Memberwise initializer. Used by the screen-driven factory below and by
    /// tests, which cannot run the screen sampler headlessly.
    init(hasNotch: Bool, collapsedFrame: NSRect, notchHeight: CGFloat) {
        self.hasNotch = hasNotch
        self.collapsedFrame = collapsedFrame
        self.notchHeight = notchHeight
    }

    // MARK: - Sampling

    /// Build geometry for the screen that currently hosts the menu bar.
    ///
    /// Returns `nil` only when there is no screen at all (headless / between
    /// display reconfiguration), which the caller treats as "skip this update".
    static func forActiveScreen() -> NotchGeometry? {
        guard let screen = activeScreen() else { return nil }
        return NotchGeometry(screen: screen)
    }

    /// The screen the menu bar lives on. `NSScreen.main` follows the key window,
    /// which we never have, so prefer the screen whose frame origin is (0,0) —
    /// that is the menu-bar screen in AppKit's global coordinate space.
    static func activeScreen() -> NSScreen? {
        let screens = NSScreen.screens
        if let primary = screens.first(where: { $0.frame.origin == .zero }) {
            return primary
        }
        return NSScreen.main ?? screens.first
    }

    /// Sample geometry for a specific screen (multi-display callers own screen
    /// selection; `forActiveScreen()` remains the single-screen convenience).
    static func sample(_ screen: NSScreen) -> NotchGeometry {
        NotchGeometry(screen: screen)
    }

    private init(screen: NSScreen) {
        let topInset = screen.safeAreaInsets.top
        let frame = screen.frame

        // A non-zero top safe-area inset on a macOS display means a notch.
        let notched = topInset > 0
        self.hasNotch = notched

        let height = notched ? topInset : NotchGeometry.fallbackHeight
        self.notchHeight = height

        let width: CGFloat
        if notched {
            // The notch is centered. `auxiliaryTopLeftArea` / `auxiliaryTopRightArea`
            // (macOS 12+) bound the usable menu-bar areas; the gap between them is
            // the notch. Fall back to a sensible default if unavailable.
            width = NotchGeometry.notchWidth(for: screen) ?? NotchGeometry.fallbackWidth
        } else {
            width = NotchGeometry.fallbackWidth
        }

        // Top-center rectangle in AppKit coordinates (origin bottom-left).
        let originX = frame.midX - (width / 2)
        let originY = frame.maxY - height
        self.collapsedFrame = NSRect(x: originX, y: originY, width: width, height: height)
    }

    /// Derive notch width from the gap between the left and right menu-bar areas.
    /// Returns `nil` if the auxiliary areas are not exposed (older hardware/OS),
    /// letting the caller use `fallbackWidth`.
    private static func notchWidth(for screen: NSScreen) -> CGFloat? {
        guard
            let leftArea = screen.auxiliaryTopLeftArea,
            let rightArea = screen.auxiliaryTopRightArea
        else {
            return nil
        }
        let gap = rightArea.minX - leftArea.maxX
        return gap > 0 ? gap : nil
    }
}
