import SwiftUI

/// Single source of truth for every duration and spring in the notch UI —
/// no scattered `0.20` / `0.22` / `0.12` literals (docs/PARITY-ROADMAP.md §2.2).
enum NotchMotion {

    /// The default morph spring (state-to-state island transitions).
    static let spring = Animation.spring(response: 0.36, dampingFraction: 0.8)

    /// Snappier spring for transient arrivals (hud/peek pop-in).
    static let transientSpring = Animation.spring(response: 0.28, dampingFraction: 0.78)

    /// Micro-interactions (hover highlights, icon scale).
    static let micro = Animation.easeOut(duration: 0.12)

    /// Default dwell before a hover on the notch expands the panel — kills
    /// accidental expansions from the pointer crossing the screen top.
    /// Settings (slice E) exposes 0.1–0.3s.
    static let defaultHoverDwell: TimeInterval = 0.15

    /// Animation for a state change, honoring Reduce Motion: springs collapse to
    /// a short fade so the island never bounces for motion-sensitive users.
    static func stateChange(reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeOut(duration: 0.15) : spring
    }

    /// Animation for a transient arrival, honoring Reduce Motion.
    static func transientArrival(reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeOut(duration: 0.15) : transientSpring
    }
}
