import Foundation

/// Optional-field decode of a single adapter update line. Diff-mode updates carry
/// only the fields that changed; a field left `nil` means "unspecified — keep the
/// previous value" (see `NowPlayingLogic.applying`). There is no way to clear a
/// field back to `nil` via a diff; a stop is modelled as `isPlaying == false`.
struct NowPlayingPayload: Equatable {
    var title: String?
    var artist: String?
    var album: String?
    var elapsed: TimeInterval?
    var duration: TimeInterval?
    var isPlaying: Bool?
    var bundleID: String?
    var artworkData: Data?

    var isEmpty: Bool {
        title == nil && artist == nil && album == nil && elapsed == nil
            && duration == nil && isPlaying == nil && bundleID == nil
            && artworkData == nil
    }
}

/// Pure now-playing math and parsing — no I/O, no `Date`, no UI. Everything the
/// model and section need to compute from a `NowPlayingState` lives here so it's
/// exhaustively CI-testable (the roadmap's "CI can" list for v0.5 §3).
///
/// Clean-room: derived from the published behavioral facts in
/// docs/PARITY-ROADMAP.md §3, not from any GPL source.
enum NowPlayingLogic {

    // MARK: Playback position

    /// `elapsed` extrapolated forward by `sinceCapture` seconds when playing,
    /// clamped to `[0, duration]` (or `[0, ∞)` when duration is unknown). Paused
    /// tracks hold position. Negative `sinceCapture` (clock skew) never rewinds
    /// past the captured value.
    static func interpolatedElapsed(
        _ state: NowPlayingState,
        sinceCapture: TimeInterval
    ) -> TimeInterval {
        let advanced = state.isPlaying
            ? state.elapsed + max(0, sinceCapture)
            : state.elapsed
        let floored = max(0, advanced)
        guard state.duration > 0 else { return floored }
        return min(floored, state.duration)
    }

    /// Seeker fraction `0...1`; `0` when duration is unknown (nothing to fill).
    static func progress(
        _ state: NowPlayingState,
        sinceCapture: TimeInterval
    ) -> Double {
        guard state.duration > 0 else { return 0 }
        return interpolatedElapsed(state, sinceCapture: sinceCapture) / state.duration
    }

    /// `m:ss` (or `h:mm:ss` past an hour) for seeker labels. Negative and
    /// non-finite inputs render as `0:00`.
    static func timeLabel(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds > 0 else { return "0:00" }
        let total = Int(seconds.rounded(.down))
        let s = total % 60
        let m = (total / 60) % 60
        let h = total / 3600
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    // MARK: Marquee

    /// Horizontal offset (points, `<= 0`) for a title that scrolls when it
    /// overflows its container. Returns `0` — no scroll — when the text fits, when
    /// the container is non-positive, or when speed is non-positive. Otherwise the
    /// text loops left through `textWidth + gap` and wraps, so a duplicate copy
    /// drawn at `+(textWidth + gap)` yields a seamless ticker.
    static func marqueeOffset(
        textWidth: Double,
        containerWidth: Double,
        gap: Double,
        speed: Double,
        elapsed: TimeInterval
    ) -> Double {
        guard containerWidth > 0, speed > 0, textWidth > containerWidth else {
            return 0
        }
        let period = textWidth + max(0, gap)
        guard period > 0 else { return 0 }
        let distance = speed * max(0, elapsed)
        let wrapped = distance.truncatingRemainder(dividingBy: period)
        return -wrapped
    }

    // MARK: Artwork cache

    /// Stable key for caching decoded artwork / extracted dominant color per
    /// track — `nil` when there's no track. Position and play/pause deliberately
    /// don't affect it, so scrubbing or pausing never busts the cache (Alcove had
    /// a per-frame dominant-color CPU leak here; this keys once per song).
    static func artworkCacheKey(_ state: NowPlayingState) -> String? {
        state.trackIdentity
    }

    // MARK: Adapter parsing

    /// Decode one JSON line from the media adapter into a partial payload.
    /// Returns `nil` only when the line isn't a JSON object (malformed / partial
    /// stream fragment) — a well-formed `{}` yields an empty payload, not `nil`.
    /// Tolerant of key-name variants and of numbers arriving as strings; unknown
    /// keys are ignored; a bad base64 artwork string drops just the artwork.
    static func parse(jsonLine: String) -> NowPlayingPayload? {
        let trimmed = jsonLine.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else {
            return nil
        }
        guard
            let object = try? JSONSerialization.jsonObject(with: data),
            let dict = object as? [String: Any]
        else { return nil }

        // Adapters vary; accept the common spellings for each field.
        var payload = NowPlayingPayload()
        payload.title = string(in: dict, keys: ["title", "Title"])
        payload.artist = string(in: dict, keys: ["artist", "Artist"])
        payload.album = string(in: dict, keys: ["album", "Album"])
        payload.elapsed = double(in: dict, keys: ["elapsed", "elapsedTime", "position"])
        payload.duration = double(in: dict, keys: ["duration", "totalDuration", "length"])
        payload.bundleID = string(in: dict, keys: ["bundleID", "bundleIdentifier", "bundle"])
        payload.isPlaying = playing(in: dict)
        if let b64 = string(in: dict, keys: ["artworkData", "artwork", "artworkBase64"]) {
            payload.artworkData = Data(base64Encoded: b64)
        }
        return payload
    }

    /// Fold a partial payload onto the previous state (diff-mode merge): every
    /// field the payload specifies overwrites; unspecified fields carry forward.
    static func applying(
        _ payload: NowPlayingPayload,
        to previous: NowPlayingState
    ) -> NowPlayingState {
        var next = previous
        if let v = payload.title { next.title = v }
        if let v = payload.artist { next.artist = v }
        if let v = payload.album { next.album = v }
        if let v = payload.elapsed { next.elapsed = max(0, v) }
        if let v = payload.duration { next.duration = max(0, v) }
        if let v = payload.isPlaying { next.isPlaying = v }
        if let v = payload.bundleID { next.bundleID = v }
        if let v = payload.artworkData { next.artworkData = v }
        return next
    }

    // MARK: - Tolerant field readers

    private static func string(in dict: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let s = dict[key] as? String { return s }
        }
        return nil
    }

    private static func double(in dict: [String: Any], keys: [String]) -> Double? {
        for key in keys {
            if let n = dict[key] as? Double { return n }
            if let n = dict[key] as? Int { return Double(n) }
            if let s = dict[key] as? String, let n = Double(s) { return n }
        }
        return nil
    }

    /// `playing`/`isPlaying` booleans, or a `playbackRate`/`rate` where `> 0`
    /// means playing (MediaRemote reports rate, not a bool).
    private static func playing(in dict: [String: Any]) -> Bool? {
        for key in ["isPlaying", "playing"] {
            if let b = dict[key] as? Bool { return b }
        }
        for key in ["playbackRate", "rate"] {
            if let n = dict[key] as? Double { return n > 0 }
            if let n = dict[key] as? Int { return n > 0 }
        }
        return nil
    }
}
