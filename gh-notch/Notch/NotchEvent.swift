import Foundation

/// Everything that can move the notch between states.
///
/// UI inputs (hover/tap/swipe/escape/clickAway) come from the panel and gesture
/// layers; posted events (peek/activity/hud) come from feature stores; `timeout`
/// comes from the auto-dismiss timer the view model runs on behalf of
/// `NotchStateMachine`.
enum NotchEvent: Equatable {
    case hoverEnter
    case hoverExit
    case tap
    case swipe(SwipeDirection)
    case escape
    case clickAway
    case peekPosted(PeekContent)
    case activityPosted(ActivityID)
    case activityDismissed(ActivityID)
    case hudEvent(HUDKind)
    case timeout(TransientKind)
}
