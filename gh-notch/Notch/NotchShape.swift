import SwiftUI

/// The drawn black island — the visible surface for every non-collapsed state
/// (collapsed keeps the v0.3 transparent "blends with the menu bar" look until
/// the `blendCollapsed` setting lands in slice E).
///
/// Top corners stay square so the surface hugs the notch/menu-bar edge; bottom
/// corners are continuous-rounded, radius per state. `UnevenRoundedRectangle`'s
/// corner radii are Animatable, so state changes spring both size and radii.
struct NotchIslandBackground: View {
    let state: NotchState

    var body: some View {
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: Self.bottomRadius(for: state),
            bottomTrailingRadius: Self.bottomRadius(for: state),
            topTrailingRadius: 0,
            style: .continuous
        )
        shape
            .fill(.black)
            .overlay(shape.strokeBorder(.white.opacity(Self.strokeOpacity(for: state)), lineWidth: 1))
    }

    /// Bottom corner radius per state: subtle on the small transient island,
    /// the familiar 22pt on the full dropdown.
    static func bottomRadius(for state: NotchState) -> CGFloat {
        switch state {
        case .collapsed:
            return 10
        case .peek, .hud, .activity:
            return 14
        case .expanded:
            return 22
        }
    }

    /// The hairline border reads well on the big surface; keep transients
    /// subtler and the collapsed strip invisible.
    static func strokeOpacity(for state: NotchState) -> Double {
        switch state {
        case .collapsed:
            return 0
        case .peek, .hud, .activity:
            return 0.08
        case .expanded:
            return 0.12
        }
    }
}
