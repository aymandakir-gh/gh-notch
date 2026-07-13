import Foundation

/// Why the expanded panel refuses to auto-collapse right now.
///
/// Replaces the OR-chain that `NotchView.syncPinnedOpen()` maintained in v0.3:
/// each feature inserts/removes its own reason and the panel is pinned while the
/// set is non-empty. Pinning suppresses `hoverExit` and `clickAway` collapse (the
/// latter fixes the v0.2 bug where clicking a system permission dialog collapsed
/// the panel out from under it); `escape` always collapses.
enum PinReason: Hashable {
    /// The command bar has text, focus, or an in-flight request.
    case commandBar
    /// A system permission dialog we triggered is on screen (e.g. Calendar).
    case permissionDialog
    /// A shelf item is being dragged out; collapsing would cancel the drag.
    case shelfDrag
}
