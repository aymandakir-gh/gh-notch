import XCTest
@testable import gh_notch

final class NowPlayingStateTests: XCTestCase {

    func testIdleHasNoTrack() {
        XCTAssertFalse(NowPlayingState.idle.hasTrack)
        XCTAssertNil(NowPlayingState.idle.trackIdentity)
    }

    func testHasTrackWithTitleOnly() {
        XCTAssertTrue(NowPlayingState(title: "T").hasTrack)
    }

    func testHasTrackWithArtistOnly() {
        XCTAssertTrue(NowPlayingState(artist: "A").hasTrack)
    }

    func testEmptyStringsDoNotCountAsTrack() {
        XCTAssertFalse(NowPlayingState(title: "", artist: "").hasTrack)
    }

    func testArtworkWithoutMetadataIsNotATrack() {
        // An app can hold a session with art but no title/artist.
        XCTAssertFalse(NowPlayingState(bundleID: "com.x", artworkData: Data([1])).hasTrack)
    }

    func testInitClampsNegativeElapsedAndDuration() {
        let s = NowPlayingState(elapsed: -10, duration: -5)
        XCTAssertEqual(s.elapsed, 0)
        XCTAssertEqual(s.duration, 0)
    }

    func testTrackIdentityDistinguishesFieldShifts() {
        // "same string in a different field" must not collide.
        let a = NowPlayingState(title: "x", artist: "")
        let b = NowPlayingState(title: "", artist: "x")
        XCTAssertNotEqual(a.trackIdentity, b.trackIdentity)
    }
}

final class FakeNowPlayingSourceTests: XCTestCase {

    func testProbeReturnsScriptedResultAndCounts() async {
        let source = FakeNowPlayingSource(probeResult: false)
        let ok = await source.probe()
        XCTAssertFalse(ok)
        XCTAssertEqual(source.probeCallCount, 1)
    }

    func testUpdatesYieldScriptedSequenceThenFinishes() async {
        let scripted = [
            NowPlayingState(title: "One", isPlaying: true),
            NowPlayingState(title: "Two", isPlaying: true),
        ]
        let source = FakeNowPlayingSource(states: scripted)
        var received: [NowPlayingState] = []
        for await state in source.updates {
            received.append(state)
        }
        XCTAssertEqual(received, scripted)
    }

    func testEmptyScriptFinishesImmediately() async {
        let source = FakeNowPlayingSource(states: [])
        var count = 0
        for await _ in source.updates { count += 1 }
        XCTAssertEqual(count, 0)
    }
}
