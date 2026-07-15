import XCTest
@testable import gh_notch

final class HUDLogicTests: XCTestCase {

    /// Build a system-defined `data1` the way the OS packs it:
    /// `keyCode` in the high word, `state` (0x0A down / 0x0B up) in the low word's
    /// high byte, auto-repeat in bit 0.
    private func data1(code: Int, state: Int, repeatFlag: Int = 0) -> Int {
        (code << 16) | (state << 8) | repeatFlag
    }

    // MARK: parseSystemDefinedKey

    func testParseVolumeUpDown() {
        let press = HUDLogic.parseSystemDefinedKey(data1: data1(code: 0, state: 0x0A))
        XCTAssertEqual(press, HUDKeyPress(key: .volumeUp, isDown: true, isRepeat: false))
    }

    func testParseVolumeUpKeyUp() {
        let press = HUDLogic.parseSystemDefinedKey(data1: data1(code: 0, state: 0x0B))
        XCTAssertEqual(press, HUDKeyPress(key: .volumeUp, isDown: false, isRepeat: false))
    }

    func testParseAllHandledCodes() {
        let cases: [(Int, MediaKey)] = [
            (0, .volumeUp), (1, .volumeDown), (7, .mute),
            (2, .brightnessUp), (3, .brightnessDown),
            (21, .keyboardBrightnessUp), (22, .keyboardBrightnessDown),
        ]
        for (code, key) in cases {
            let press = HUDLogic.parseSystemDefinedKey(data1: data1(code: code, state: 0x0A))
            XCTAssertEqual(press?.key, key, "code \(code)")
            XCTAssertEqual(press?.isDown, true)
        }
    }

    func testParseRepeatFlag() {
        let press = HUDLogic.parseSystemDefinedKey(data1: data1(code: 0, state: 0x0A, repeatFlag: 1))
        XCTAssertEqual(press?.isRepeat, true)
    }

    func testParseUnknownKeyCodeReturnsNil() {
        // NX_KEYTYPE_PLAY (16) — a media key we intentionally don't drive a HUD for.
        XCTAssertNil(HUDLogic.parseSystemDefinedKey(data1: data1(code: 16, state: 0x0A)))
    }

    func testParseInvalidStateReturnsNil() {
        XCTAssertNil(HUDLogic.parseSystemDefinedKey(data1: data1(code: 0, state: 0x0C)))
    }

    func testParseNegativeData1ReturnsNil() {
        XCTAssertNil(HUDLogic.parseSystemDefinedKey(data1: -1))
    }

    // MARK: hudKind

    func testHUDKindMapping() {
        XCTAssertEqual(HUDLogic.hudKind(for: .volumeUp), .volume)
        XCTAssertEqual(HUDLogic.hudKind(for: .mute), .volume)
        XCTAssertEqual(HUDLogic.hudKind(for: .brightnessDown), .brightness)
        XCTAssertEqual(HUDLogic.hudKind(for: .keyboardBrightnessUp), .keyboardBacklight)
    }

    // MARK: filledSegments

    func testFilledSegmentsEndpoints() {
        XCTAssertEqual(HUDLogic.filledSegments(level: 0, total: 16), 0)
        XCTAssertEqual(HUDLogic.filledSegments(level: 1, total: 16), 16)
        XCTAssertEqual(HUDLogic.filledSegments(level: 0.5, total: 16), 8)
    }

    func testFilledSegmentsRoundsToNearest() {
        XCTAssertEqual(HUDLogic.filledSegments(level: 0.53, total: 16), 8)  // 8.48 → 8
        XCTAssertEqual(HUDLogic.filledSegments(level: 0.56, total: 16), 9)  // 8.96 → 9
    }

    func testFilledSegmentsClampsAndGuardsTotal() {
        XCTAssertEqual(HUDLogic.filledSegments(level: 2, total: 16), 16)
        XCTAssertEqual(HUDLogic.filledSegments(level: -1, total: 16), 0)
        XCTAssertEqual(HUDLogic.filledSegments(level: 0.5, total: 0), 0)
    }

    // MARK: glowStage

    func testGlowStageThreshold() {
        XCTAssertEqual(HUDLogic.glowStage(level: 0.5), .normal)
        XCTAssertEqual(HUDLogic.glowStage(level: 0.8), .normal)   // not strictly above 80%
        XCTAssertEqual(HUDLogic.glowStage(level: 0.85), .hot)
        XCTAssertEqual(HUDLogic.glowStage(level: 1.0), .hot)
        XCTAssertEqual(HUDLogic.glowStage(level: 2.0), .hot)      // clamped
        XCTAssertEqual(HUDLogic.glowStage(level: -1), .normal)
    }

    // MARK: percentText

    func testPercentText() {
        XCTAssertEqual(HUDLogic.percentText(level: 0), "0%")
        XCTAssertEqual(HUDLogic.percentText(level: 1), "100%")
        XCTAssertEqual(HUDLogic.percentText(level: 0.5), "50%")
        XCTAssertEqual(HUDLogic.percentText(level: 0.999), "100%")
        XCTAssertEqual(HUDLogic.percentText(level: 1.5), "100%")   // clamped
    }

    // MARK: step

    func testStepGrid() {
        XCTAssertEqual(HUDLogic.step(fine: false), 1.0 / 16.0, accuracy: 1e-12)
        XCTAssertEqual(HUDLogic.step(fine: true), 1.0 / 64.0, accuracy: 1e-12)
    }

    // MARK: coalesceLatestPerKind

    func testCoalesceKeepsLatestPerKindInFirstSeenOrder() {
        let events = [
            HUDEvent(kind: .volume, level: 0.3),
            HUDEvent(kind: .volume, level: 0.5),
            HUDEvent(kind: .brightness, level: 0.7),
            HUDEvent(kind: .volume, level: 0.9),
        ]
        let result = HUDLogic.coalesceLatestPerKind(events)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].kind, .volume)
        XCTAssertEqual(result[0].level, 0.9, accuracy: 1e-9)
        XCTAssertEqual(result[1].kind, .brightness)
        XCTAssertEqual(result[1].level, 0.7, accuracy: 1e-9)
    }

    func testCoalesceEmptyAndSingle() {
        XCTAssertEqual(HUDLogic.coalesceLatestPerKind([]).count, 0)
        let one = [HUDEvent(kind: .charging, isOn: true)]
        XCTAssertEqual(HUDLogic.coalesceLatestPerKind(one), one)
    }

    // MARK: HUDEvent clamping

    func testHUDEventClampsLevel() {
        XCTAssertEqual(HUDEvent(kind: .volume, level: 2).level, 1)
        XCTAssertEqual(HUDEvent(kind: .volume, level: -1).level, 0)
    }
}
