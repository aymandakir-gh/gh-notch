import Foundation

/// A stream of now-playing snapshots from one backend. `NowPlayingModel` (slice B)
/// probes a chain of these — adapter subprocess → direct MediaRemote → AppleScript
/// polling — and subscribes to the first whose `probe()` succeeds, re-probing on
/// failure. Abstracting behind a protocol keeps the model testable with a fake and
/// keeps all private-API/subprocess I/O out of the pure and model layers.
///
/// v0.5 core (docs/PARITY-ROADMAP.md §3). Real backends land in later slices,
/// gated on a runnable build + the signing decision; the fake ships now so the
/// fallback-chain and model logic are testable today.
protocol NowPlayingSource {
    /// A snapshot every time the system's now-playing info changes.
    var updates: AsyncStream<NowPlayingState> { get }
    /// Whether this backend can serve updates on the current OS/session. Cheap and
    /// side-effect-free where possible; the model uses it to pick the live source.
    func probe() async -> Bool
}

/// In-memory `NowPlayingSource` for unit tests and SwiftUI previews. Emits a
/// scripted sequence of states, then finishes; `probeResult` scripts the
/// fallback-chain selection.
final class FakeNowPlayingSource: NowPlayingSource {
    private let scripted: [NowPlayingState]
    private let probeResult: Bool
    private(set) var probeCallCount = 0

    init(states: [NowPlayingState] = [], probeResult: Bool = true) {
        self.scripted = states
        self.probeResult = probeResult
    }

    var updates: AsyncStream<NowPlayingState> {
        let states = scripted
        return AsyncStream { continuation in
            for state in states {
                continuation.yield(state)
            }
            continuation.finish()
        }
    }

    func probe() async -> Bool {
        probeCallCount += 1
        return probeResult
    }
}
