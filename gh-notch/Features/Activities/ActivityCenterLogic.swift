import Foundation

/// The pure heart of the live-activity engine (docs/PARITY-ROADMAP.md §5): all
/// ordering, cycling, dismiss/restore, coalescing, priority preemption, and
/// expiry as value-in → value-out transforms. The `@MainActor @Observable`
/// `ActivityCenter` (a later slice) is a thin shell over this. No I/O, no `Date`.
///
/// Presentation model: `active` is kept sorted highest-priority-first; the
/// frontmost slot is `active[cycleIndex]`. Posting resets `cycleIndex` to 0, so a
/// higher-priority post naturally preempts (it sorts to the front) while a
/// lower-priority post never steals focus from an existing higher one. The user
/// cycles through simultaneous activities with `cycled`.
enum ActivityCenterLogic {

    struct State: Equatable {
        /// Sorted: priority desc, then `postedAt` desc, then `id` asc (stable).
        var active: [Activity]
        /// Restorable dismissed activities, most-recently-dismissed first.
        var dismissed: [Activity]
        /// Index of the frontmost activity within `active`.
        var cycleIndex: Int

        static let empty = State(active: [], dismissed: [], cycleIndex: 0)
    }

    /// Deterministic display order: priority desc, recency desc, id asc.
    static func ordered(_ activities: [Activity]) -> [Activity] {
        activities.sorted { lhs, rhs in
            if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
            if lhs.postedAt != rhs.postedAt { return lhs.postedAt > rhs.postedAt }
            return lhs.id < rhs.id
        }
    }

    /// The activity currently shown, if any.
    static func frontmost(_ state: State) -> Activity? {
        guard state.active.indices.contains(state.cycleIndex) else {
            return state.active.first
        }
        return state.active[state.cycleIndex]
    }

    /// Post (or update) an activity. Same `id` coalesces — replaces in place
    /// rather than duplicating — and a matching restorable is revived out of the
    /// dismissed set. `cycleIndex` resets to 0 so the highest-priority activity is
    /// frontmost (preemption).
    static func posting(_ activity: Activity, into state: State) -> State {
        var active = state.active.filter { $0.id != activity.id }
        let dismissed = state.dismissed.filter { $0.id != activity.id }
        active.append(activity)
        return State(active: ordered(active), dismissed: dismissed, cycleIndex: 0)
    }

    /// Step the frontmost pointer through simultaneous activities (wrap-around).
    /// No-op with 0 or 1 active.
    static func cycled(_ state: State, forward: Bool) -> State {
        let count = state.active.count
        guard count > 1 else { return state }
        let clampedCurrent = min(max(0, state.cycleIndex), count - 1)
        let next = forward
            ? (clampedCurrent + 1) % count
            : (clampedCurrent - 1 + count) % count
        var copy = state
        copy.cycleIndex = next
        return copy
    }

    /// Dismiss the frontmost activity. A `.restorable` one moves to the front of
    /// the dismissed set; a `.remove` one is gone. `cycleIndex` clamps into the
    /// shrunken list.
    static func dismissingFrontmost(_ state: State) -> State {
        guard let front = frontmost(state) else { return state }
        let active = state.active.filter { $0.id != front.id }
        var dismissed = state.dismissed
        if front.dismissBehavior == .restorable {
            dismissed = [front] + dismissed.filter { $0.id != front.id }
        }
        return State(
            active: active,
            dismissed: dismissed,
            cycleIndex: clampIndex(state.cycleIndex, count: active.count)
        )
    }

    /// Drop every active activity whose hard deadline has passed (`expiresAt` on
    /// or before `now`). Sticky (`expiresAt == nil`) activities are untouched.
    static func expiring(_ state: State, now: TimeInterval) -> State {
        let active = state.active.filter { activity in
            guard let expiry = activity.expiresAt else { return true }
            return expiry > now
        }
        guard active.count != state.active.count else { return state }
        return State(
            active: active,
            dismissed: state.dismissed,
            cycleIndex: clampIndex(state.cycleIndex, count: active.count)
        )
    }

    /// Bring a dismissed activity back into the active set and focus it. Restore
    /// is an explicit user action on a specific item, so it surfaces that item
    /// (`cycleIndex` points at it) even if a higher-priority activity is
    /// active — unlike automatic `posting`, where priority governs the front
    /// slot. No-op if the id isn't in the dismissed set.
    static func restoring(id: String, in state: State) -> State {
        guard let revived = state.dismissed.first(where: { $0.id == id }) else {
            return state
        }
        let dismissed = state.dismissed.filter { $0.id != id }
        let active = ordered(state.active.filter { $0.id != id } + [revived])
        let index = active.firstIndex { $0.id == id } ?? 0
        return State(active: active, dismissed: dismissed, cycleIndex: index)
    }

    /// Clamp a cycle index into a list of `count` items (0 when empty).
    private static func clampIndex(_ index: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return min(max(0, index), count - 1)
    }
}
