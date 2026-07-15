import Foundation

/// The now-playing backends, in fixed fallback priority (docs/PARITY-ROADMAP.md
/// §3): the mediaremote-adapter subprocess first, then a direct MediaRemote
/// dlopen, then AppleScript polling. The `@MainActor @Observable NowPlayingModel`
/// (a later, subprocess/private-API-gated slice) owns the real backends; this
/// enum + `NowPlayingSourceSelection` are the pure selection policy it runs.
enum NowPlayingBackend: CaseIterable, Equatable {
    case adapter
    case directMediaRemote
    case appleScript
}

/// Pure fallback-chain selection — no subprocess, no dlopen. Given which backends
/// probed OK, decide which to use; re-selection always prefers the highest-priority
/// available backend so a recovered adapter is chosen over a lower fallback, and a
/// failed current backend drops to the next. Fully CI-testable. Clean-room.
enum NowPlayingSourceSelection {

    /// Fixed priority order: adapter → direct MediaRemote → AppleScript.
    static let order: [NowPlayingBackend] = [.adapter, .directMediaRemote, .appleScript]

    /// The highest-priority backend whose probe succeeded, or `nil` if none can
    /// serve now-playing on this system/session.
    static func select(probes: [NowPlayingBackend: Bool]) -> NowPlayingBackend? {
        order.first { probes[$0] == true }
    }

    /// Re-evaluate the active backend against fresh probes. Always prefers the
    /// top-of-chain available backend, so recovery (adapter comes back) and
    /// failure (current backend dies → fall to next) are the same operation.
    /// `current` is accepted for call-site clarity; the decision only needs the
    /// probes.
    static func reselect(
        current: NowPlayingBackend?,
        probes: [NowPlayingBackend: Bool]
    ) -> NowPlayingBackend? {
        select(probes: probes)
    }

    /// Whether the direct-MediaRemote dlopen path is even a candidate: only on
    /// macOS earlier than 15.4, where `mediaremoted`'s entitlement gate doesn't yet
    /// apply (§3). On 15.4+ the adapter subprocess is the only private route.
    static func directMediaRemoteEligible(osMajor: Int, osMinor: Int) -> Bool {
        if osMajor != 15 { return osMajor < 15 }
        return osMinor < 4
    }
}
