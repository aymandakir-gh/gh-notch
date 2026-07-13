import Foundation

/// How long each transient state stays up before auto-dismissing. Injected into
/// the machine so tests (and later Settings) can tune them; one place, no
/// scattered literals.
struct TransientDurations: Equatable {
    var peek: TimeInterval = 2.0
    var hud: TimeInterval = 1.5
    var activity: TimeInterval = 5.0

    static let standard = TransientDurations()
}

/// Result of feeding one event to the machine.
struct NotchTransition: Equatable {
    /// The state to present next (may equal the current state — a no-op).
    let next: NotchState
    /// Non-nil: (re)start the auto-dismiss timer for `next`'s transient with
    /// this duration. nil while `next` is a transient: leave any running timer
    /// untouched. nil otherwise: no timer.
    let autoDismissAfter: TimeInterval?
}

/// Pure transition table for the notch panel. No AppKit, no timers, no side
/// effects — `NotchViewModel` owns the clock and feeds `timeout` events back in.
///
/// Priority rules (docs/PARITY-ROADMAP.md §2.1):
/// - hud > activity > peek: a higher-priority transient replaces a lower one;
///   a lower-priority post is ignored while a higher one is showing. (v0.7's
///   ActivityCenter re-posts activities that lost to a hud.)
/// - `expanded` outranks all transients: nothing interrupts the open panel.
/// - `pinned` suppresses `hoverExit`/`clickAway` collapse; `escape` always wins.
/// - A `timeout` only dismisses the transient kind that started it, so a stale
///   timer can never kill a state it didn't schedule.
enum NotchStateMachine {

    static func transition(
        from state: NotchState,
        on event: NotchEvent,
        pinned: Bool = false,
        durations: TransientDurations = .standard
    ) -> NotchTransition {
        switch event {

        case .hudEvent(let kind):
            if case .expanded = state { return stay(state) }
            return NotchTransition(next: .hud(kind), autoDismissAfter: durations.hud)

        case .activityPosted(let id):
            switch state {
            case .expanded, .hud:
                return stay(state)
            case .collapsed, .peek, .activity:
                return NotchTransition(next: .activity(id), autoDismissAfter: durations.activity)
            }

        case .peekPosted(let content):
            switch state {
            case .collapsed, .peek:
                return NotchTransition(next: .peek(content), autoDismissAfter: durations.peek)
            case .expanded, .hud, .activity:
                return stay(state)
            }

        case .activityDismissed(let id):
            if case .activity(let current) = state, current == id {
                return NotchTransition(next: .collapsed, autoDismissAfter: nil)
            }
            return stay(state)

        case .timeout(let kind):
            switch (state, kind) {
            case (.peek, .peek), (.hud, .hud), (.activity, .activity):
                return NotchTransition(next: .collapsed, autoDismissAfter: nil)
            default:
                return stay(state) // stale timer — never dismiss a different state
            }

        case .hoverEnter:
            switch state {
            case .collapsed, .peek, .activity:
                return NotchTransition(next: .expanded, autoDismissAfter: nil)
            case .hud, .expanded:
                // Hovering a hud must not yank the panel open mid volume-change.
                return stay(state)
            }

        case .tap:
            if case .expanded = state { return stay(state) }
            return NotchTransition(next: .expanded, autoDismissAfter: nil)

        case .swipe(let direction):
            return transitionForSwipe(direction, from: state, pinned: pinned)

        case .escape:
            if case .collapsed = state { return stay(state) }
            return NotchTransition(next: .collapsed, autoDismissAfter: nil)

        case .hoverExit, .clickAway:
            if case .expanded = state, !pinned {
                return NotchTransition(next: .collapsed, autoDismissAfter: nil)
            }
            return stay(state)
        }
    }

    private static func transitionForSwipe(
        _ direction: SwipeDirection,
        from state: NotchState,
        pinned: Bool
    ) -> NotchTransition {
        switch direction {
        case .down:
            if case .expanded = state { return stay(state) }
            return NotchTransition(next: .expanded, autoDismissAfter: nil)
        case .up:
            switch state {
            case .collapsed:
                return stay(state)
            case .expanded:
                // A stray swipe while typing must not close the command bar.
                return pinned ? stay(state) : NotchTransition(next: .collapsed, autoDismissAfter: nil)
            case .peek, .hud, .activity:
                return NotchTransition(next: .collapsed, autoDismissAfter: nil)
            }
        case .left, .right:
            return stay(state) // reserved: v0.5 track skip / tab switch
        }
    }

    private static func stay(_ state: NotchState) -> NotchTransition {
        NotchTransition(next: state, autoDismissAfter: nil)
    }
}
