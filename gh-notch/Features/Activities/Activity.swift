import Foundation

/// A single transient live activity — a battery warning, a device-connect
/// notice, a running timer, a download's progress. Providers (later, source-gated
/// slices) build these; `ActivityCenterLogic` orders, cycles, dismisses, and
/// restores them purely.
///
/// Times are plain `TimeInterval`s on whatever monotonic clock the model feeds in
/// (never `Date` here) so the whole engine stays pure and CI-testable — the
/// roadmap's v0.7 §5 "CI can" list is ~70% this file + `ActivityCenterLogic`.
/// Clean-room from the roadmap's behavioral description; no GPL source (§9).
struct Activity: Identifiable, Equatable {

    /// The first-party providers the roadmap enumerates (§5). No raw-string
    /// backing needed — the set is closed and first-party.
    enum Kind: Equatable {
        case battery
        case deviceConnect
        case focus
        case timer
        case download
        case screenRecording
        case calendarCountdown
    }

    /// What happens when the user swipes the activity away.
    enum DismissBehavior: Equatable {
        /// Leaves the center entirely (a one-shot notice).
        case remove
        /// Moves to the restorable set so it can be brought back (`restoring`).
        case restorable
    }

    let id: String
    let kind: Kind
    /// Higher preempts lower for the frontmost slot. Ties break by recency.
    let priority: Int
    var title: String
    var subtitle: String?
    /// 0…1 for determinate activities (download, timer); `nil` = indeterminate.
    var progress: Double?
    /// When this was posted, on the model's clock. Recency tie-breaker.
    let postedAt: TimeInterval
    /// Hard deadline on the model's clock; `nil` = sticky until dismissed.
    let expiresAt: TimeInterval?
    var dismissBehavior: DismissBehavior

    init(
        id: String,
        kind: Kind,
        priority: Int = 0,
        title: String,
        subtitle: String? = nil,
        progress: Double? = nil,
        postedAt: TimeInterval = 0,
        expiresAt: TimeInterval? = nil,
        dismissBehavior: DismissBehavior = .remove
    ) {
        self.id = id
        self.kind = kind
        self.priority = priority
        self.title = title
        self.subtitle = subtitle
        self.progress = progress.map { min(1, max(0, $0)) }
        self.postedAt = postedAt
        self.expiresAt = expiresAt
        self.dismissBehavior = dismissBehavior
    }
}
