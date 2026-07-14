import Foundation

/// A pure snapshot of what's playing system-wide, as of the moment it was
/// captured. The wall-clock instant of capture is NOT stored here — it lives in
/// the model (`NowPlayingModel`, slice B), which extrapolates `elapsed` forward
/// via `NowPlayingLogic.interpolatedElapsed(_:sinceCapture:)`. Keeping the
/// timestamp out keeps this type cleanly `Equatable` and trivially testable.
///
/// v0.5 core (docs/PARITY-ROADMAP.md §3). Clean-room: shaped from the roadmap's
/// behavioral description, not from any GPL reference implementation.
struct NowPlayingState: Equatable {
    var title: String?
    var artist: String?
    var album: String?
    /// Playback position in seconds at capture time. Clamped `>= 0`.
    var elapsed: TimeInterval
    /// Track length in seconds. `0` means unknown (live streams, ads).
    var duration: TimeInterval
    var isPlaying: Bool
    /// Bundle id of the app that owns the session (e.g. `com.spotify.client`).
    var bundleID: String?
    /// Raw artwork bytes (JPEG/PNG as delivered). Decoding/color extraction is a
    /// view concern, cached by `NowPlayingLogic.artworkCacheKey`.
    var artworkData: Data?

    init(
        title: String? = nil,
        artist: String? = nil,
        album: String? = nil,
        elapsed: TimeInterval = 0,
        duration: TimeInterval = 0,
        isPlaying: Bool = false,
        bundleID: String? = nil,
        artworkData: Data? = nil
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.elapsed = max(0, elapsed)
        self.duration = max(0, duration)
        self.isPlaying = isPlaying
        self.bundleID = bundleID
        self.artworkData = artworkData
    }

    /// Nothing is playing / no session exists — the collapsed-and-empty baseline.
    static let idle = NowPlayingState()

    /// True once there's anything worth showing (a title or artist). Art or
    /// bundle id alone don't count — an app can hold a session with no metadata.
    var hasTrack: Bool { title?.isEmpty == false || artist?.isEmpty == false }

    /// Stable identity of the *track* (not the playback position): the tuple that,
    /// when unchanged, means "same song" — used to detect track changes (peek
    /// trigger) and to key the artwork cache. `nil` when there's no track.
    var trackIdentity: String? {
        guard hasTrack else { return nil }
        // Unit-separator joins avoid "a|b" vs "" + "a|b" collisions.
        return [bundleID, title, artist, album]
            .map { $0 ?? "" }
            .joined(separator: "\u{1f}")
    }
}
