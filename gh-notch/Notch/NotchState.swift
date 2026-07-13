import Foundation

/// The notch panel's presentation state.
///
/// v0.4 introduces the full state space the parity ladder needs
/// (docs/PARITY-ROADMAP.md): transient `peek`/`activity`/`hud` states are wired
/// into the machine and layout now, and their payloads grow real content in
/// v0.5–v0.7. Transitions live in `NotchStateMachine`; sizes in `NotchLayout`.
enum NotchState: Equatable {
    /// Idle strip flanking the notch (or the pill on no-notch displays).
    case collapsed
    /// Compact transient info strip (e.g. track change). Auto-dismisses.
    case peek(PeekContent)
    /// A live activity's compact presentation (timer, download…). Auto-dismisses.
    case activity(ActivityID)
    /// A system HUD (volume, brightness…). Highest-priority transient.
    case hud(HUDKind)
    /// The full dropdown surface.
    case expanded
}

/// Payload for `NotchState.peek`. Placeholder shape until v0.5 (now-playing
/// track-change peeks) gives it real content; the `id` keys timer restarts.
struct PeekContent: Equatable {
    let id: String
}

/// Identity of a live activity (v0.7 `ActivityCenter` owns the real registry).
struct ActivityID: Hashable {
    let raw: String
}

/// The system HUD kinds v0.6 renders. Defined now so the state machine and
/// layout are final before the HUD feature lands.
enum HUDKind: Equatable {
    case volume
    case brightness
    case keyboardBacklight
    case capsLock
    case charging
}

/// Which transient a timer belongs to. `NotchEvent.timeout` carries this so a
/// stale timer can never dismiss a state it didn't start (e.g. a peek timer
/// firing after a hud replaced the peek).
enum TransientKind: Equatable {
    case peek
    case hud
    case activity
}

/// Committed swipe directions emitted by the gesture layer (slice D).
enum SwipeDirection: Equatable {
    case up
    case down
    case left
    case right
}
