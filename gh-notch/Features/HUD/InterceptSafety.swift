import Foundation

/// Fail-safe for the media-key interceptor (docs/PARITY-ROADMAP.md §4). When the
/// interceptor swallows a volume/brightness/keyboard key it must then apply the
/// change itself — if that silently fails, the user would be left unable to change
/// volume at all. So we watch the outcome: a swallowed key that produces **no
/// value change while not already at a rail** is a real failure; two in a row for
/// a key class disable interception for that class (the key passes through to the
/// system again), until a device change or tap re-arm resets it.
///
/// Pure state machine — no CGEvent, no CoreAudio — so the whole safety policy is
/// exhaustively CI-testable. `atRail` (pressing up at max / down at min) is a
/// legitimate no-op and must never count as a failure. Original clean-room work.
enum InterceptSafety {

    struct State: Equatable {
        /// Consecutive real failures per key class.
        var failures: [HUDKind: Int] = [:]
        /// Key classes whose interception is currently backed off.
        var disabled: Set<HUDKind> = []

        static let armed = State()
    }

    /// Consecutive real failures before backing a key class off. Two (not one)
    /// tolerates a single fluke without ever risking a lasting lockout.
    static let failureThreshold = 2

    /// Record the outcome of a swallowed key press.
    /// - `changed`: the value actually moved after we applied it.
    /// - `atRail`: the value was already at the extreme in the pressed direction
    ///   (a legitimate no-op — never a failure).
    static func recording(
        _ state: State,
        keyClass: HUDKind,
        changed: Bool,
        atRail: Bool
    ) -> State {
        var next = state
        if changed || atRail {
            next.failures[keyClass] = 0
            return next
        }
        let count = (next.failures[keyClass] ?? 0) + 1
        next.failures[keyClass] = count
        if count >= failureThreshold {
            next.disabled.insert(keyClass)
        }
        return next
    }

    /// Whether we should still intercept (swallow) keys for this class.
    static func isIntercepting(_ state: State, keyClass: HUDKind) -> Bool {
        !state.disabled.contains(keyClass)
    }

    /// Re-arm everything — call on a default-device change or when the event tap
    /// is re-enabled after `tapDisabledByTimeout`/`ByUserInput`.
    static func reset(_ state: State) -> State {
        .armed
    }
}
