import XCTest
@testable import gh_notch

final class NowPlayingLogicTests: XCTestCase {

    private func track(
        elapsed: TimeInterval = 30,
        duration: TimeInterval = 200,
        playing: Bool = true
    ) -> NowPlayingState {
        NowPlayingState(
            title: "Song", artist: "Artist", album: "Album",
            elapsed: elapsed, duration: duration, isPlaying: playing,
            bundleID: "com.example.player"
        )
    }

    // MARK: interpolatedElapsed

    func testInterpolationAdvancesWhilePlaying() {
        let s = track(elapsed: 30, playing: true)
        XCTAssertEqual(NowPlayingLogic.interpolatedElapsed(s, sinceCapture: 5), 35, accuracy: 1e-9)
    }

    func testInterpolationHoldsWhilePaused() {
        let s = track(elapsed: 30, playing: false)
        XCTAssertEqual(NowPlayingLogic.interpolatedElapsed(s, sinceCapture: 5), 30, accuracy: 1e-9)
    }

    func testInterpolationClampsToDuration() {
        let s = track(elapsed: 195, duration: 200, playing: true)
        XCTAssertEqual(NowPlayingLogic.interpolatedElapsed(s, sinceCapture: 30), 200, accuracy: 1e-9)
    }

    func testInterpolationUnknownDurationDoesNotClamp() {
        let s = track(elapsed: 100, duration: 0, playing: true)
        XCTAssertEqual(NowPlayingLogic.interpolatedElapsed(s, sinceCapture: 50), 150, accuracy: 1e-9)
    }

    func testInterpolationNeverRewindsOnNegativeSkew() {
        let s = track(elapsed: 30, playing: true)
        XCTAssertEqual(NowPlayingLogic.interpolatedElapsed(s, sinceCapture: -10), 30, accuracy: 1e-9)
    }

    // MARK: progress

    func testProgressMidTrack() {
        let s = track(elapsed: 50, duration: 200, playing: false)
        XCTAssertEqual(NowPlayingLogic.progress(s, sinceCapture: 0), 0.25, accuracy: 1e-9)
    }

    func testProgressUnknownDurationIsZero() {
        let s = track(elapsed: 50, duration: 0, playing: true)
        XCTAssertEqual(NowPlayingLogic.progress(s, sinceCapture: 10), 0, accuracy: 1e-9)
    }

    // MARK: timeLabel

    func testTimeLabelUnderAnHour() {
        XCTAssertEqual(NowPlayingLogic.timeLabel(0), "0:00")
        XCTAssertEqual(NowPlayingLogic.timeLabel(5), "0:05")
        XCTAssertEqual(NowPlayingLogic.timeLabel(65), "1:05")
        XCTAssertEqual(NowPlayingLogic.timeLabel(599), "9:59")
    }

    func testTimeLabelOverAnHour() {
        XCTAssertEqual(NowPlayingLogic.timeLabel(3661), "1:01:01")
    }

    func testTimeLabelHandlesNegativeAndNonFinite() {
        XCTAssertEqual(NowPlayingLogic.timeLabel(-5), "0:00")
        XCTAssertEqual(NowPlayingLogic.timeLabel(.nan), "0:00")
        XCTAssertEqual(NowPlayingLogic.timeLabel(.infinity), "0:00")
    }

    // MARK: marqueeOffset

    func testMarqueeNoScrollWhenTextFits() {
        XCTAssertEqual(
            NowPlayingLogic.marqueeOffset(textWidth: 80, containerWidth: 100, gap: 20, speed: 30, elapsed: 5),
            0, accuracy: 1e-9)
    }

    func testMarqueeNoScrollWhenSpeedZero() {
        XCTAssertEqual(
            NowPlayingLogic.marqueeOffset(textWidth: 200, containerWidth: 100, gap: 20, speed: 0, elapsed: 5),
            0, accuracy: 1e-9)
    }

    func testMarqueeScrollsLeft() {
        // textWidth 200 > container 100 → scroll at 30 pt/s for 2 s = -60.
        XCTAssertEqual(
            NowPlayingLogic.marqueeOffset(textWidth: 200, containerWidth: 100, gap: 20, speed: 30, elapsed: 2),
            -60, accuracy: 1e-9)
    }

    func testMarqueeWrapsAtPeriod() {
        // period = textWidth + gap = 220. distance = 30 * 8 = 240 → wraps to 20 → -20.
        XCTAssertEqual(
            NowPlayingLogic.marqueeOffset(textWidth: 200, containerWidth: 100, gap: 20, speed: 30, elapsed: 8),
            -20, accuracy: 1e-9)
    }

    func testMarqueeNonPositiveContainerIsZero() {
        XCTAssertEqual(
            NowPlayingLogic.marqueeOffset(textWidth: 200, containerWidth: 0, gap: 20, speed: 30, elapsed: 5),
            0, accuracy: 1e-9)
    }

    // MARK: artworkCacheKey

    func testCacheKeyStableAcrossPositionAndPlayState() {
        let a = track(elapsed: 10, playing: true)
        let b = track(elapsed: 180, playing: false)
        XCTAssertEqual(NowPlayingLogic.artworkCacheKey(a), NowPlayingLogic.artworkCacheKey(b))
        XCTAssertNotNil(NowPlayingLogic.artworkCacheKey(a))
    }

    func testCacheKeyChangesWithTrack() {
        var a = track()
        a.title = "One"
        var b = track()
        b.title = "Two"
        XCTAssertNotEqual(NowPlayingLogic.artworkCacheKey(a), NowPlayingLogic.artworkCacheKey(b))
    }

    func testCacheKeyNilWhenNoTrack() {
        XCTAssertNil(NowPlayingLogic.artworkCacheKey(.idle))
    }

    // MARK: parse

    func testParseWellFormedLine() {
        let line = #"{"title":"T","artist":"A","album":"Al","elapsed":12.5,"duration":200,"playbackRate":1,"bundleID":"com.x"}"#
        let p = NowPlayingLogic.parse(jsonLine: line)
        XCTAssertEqual(p?.title, "T")
        XCTAssertEqual(p?.artist, "A")
        XCTAssertEqual(p?.album, "Al")
        XCTAssertEqual(p?.elapsed, 12.5)
        XCTAssertEqual(p?.duration, 200)
        XCTAssertEqual(p?.isPlaying, true)
        XCTAssertEqual(p?.bundleID, "com.x")
    }

    func testParsePausedFromRateZero() {
        let p = NowPlayingLogic.parse(jsonLine: #"{"playbackRate":0}"#)
        XCTAssertEqual(p?.isPlaying, false)
    }

    func testParseNumbersAsStrings() {
        let p = NowPlayingLogic.parse(jsonLine: #"{"elapsed":"30.0","duration":"180"}"#)
        XCTAssertEqual(p?.elapsed, 30)
        XCTAssertEqual(p?.duration, 180)
    }

    func testParseMalformedReturnsNil() {
        XCTAssertNil(NowPlayingLogic.parse(jsonLine: "not json"))
        XCTAssertNil(NowPlayingLogic.parse(jsonLine: ""))
        XCTAssertNil(NowPlayingLogic.parse(jsonLine: "   "))
        XCTAssertNil(NowPlayingLogic.parse(jsonLine: "[1,2,3]")) // array, not object
        XCTAssertNil(NowPlayingLogic.parse(jsonLine: #"{"title":"partial"#)) // truncated
    }

    func testParseEmptyObjectIsEmptyPayloadNotNil() {
        let p = NowPlayingLogic.parse(jsonLine: "{}")
        XCTAssertNotNil(p)
        XCTAssertEqual(p?.isEmpty, true)
    }

    func testParseUnknownKeysIgnored() {
        let p = NowPlayingLogic.parse(jsonLine: #"{"title":"T","somethingNew":42}"#)
        XCTAssertEqual(p?.title, "T")
    }

    func testParseArtworkBase64() {
        let raw = Data([0xDE, 0xAD, 0xBE, 0xEF])
        let line = "{\"artworkData\":\"\(raw.base64EncodedString())\"}"
        XCTAssertEqual(NowPlayingLogic.parse(jsonLine: line)?.artworkData, raw)
    }

    func testParseBadArtworkDropsOnlyArtwork() {
        let p = NowPlayingLogic.parse(jsonLine: #"{"title":"T","artwork":"@@@not base64@@@"}"#)
        XCTAssertEqual(p?.title, "T")
        XCTAssertNil(p?.artworkData)
    }

    // MARK: applying (diff merge)

    func testApplyingOverwritesOnlySpecifiedFields() {
        let base = NowPlayingState(
            title: "Old", artist: "A", elapsed: 10, duration: 100,
            isPlaying: true, bundleID: "com.x")
        var diff = NowPlayingPayload()
        diff.title = "New"
        diff.elapsed = 0
        let merged = NowPlayingLogic.applying(diff, to: base)
        XCTAssertEqual(merged.title, "New")
        XCTAssertEqual(merged.elapsed, 0)
        XCTAssertEqual(merged.artist, "A")       // untouched
        XCTAssertEqual(merged.duration, 100)      // untouched
        XCTAssertEqual(merged.isPlaying, true)    // untouched
    }

    func testApplyingEmptyPayloadIsIdentity() {
        let base = track()
        XCTAssertEqual(NowPlayingLogic.applying(NowPlayingPayload(), to: base), base)
    }

    func testParseThenApplyArtworkArrivesLate() {
        // A track without art, then a later diff carrying only the artwork.
        let first = NowPlayingLogic.parse(jsonLine: #"{"title":"T","artist":"A","playbackRate":1}"#)
        let s1 = NowPlayingLogic.applying(first ?? NowPlayingPayload(), to: .idle)
        XCTAssertNil(s1.artworkData)
        XCTAssertEqual(s1.title, "T")

        let art = Data([1, 2, 3])
        let line = "{\"artworkData\":\"\(art.base64EncodedString())\"}"
        let second = NowPlayingLogic.parse(jsonLine: line)
        let s2 = NowPlayingLogic.applying(second ?? NowPlayingPayload(), to: s1)
        XCTAssertEqual(s2.artworkData, art)
        XCTAssertEqual(s2.title, "T")     // preserved across the diff
        XCTAssertEqual(s2.isPlaying, true)
    }

    func testApplyingClampsNegativeElapsed() {
        var diff = NowPlayingPayload()
        diff.elapsed = -5
        let merged = NowPlayingLogic.applying(diff, to: track())
        XCTAssertEqual(merged.elapsed, 0)
    }
}
