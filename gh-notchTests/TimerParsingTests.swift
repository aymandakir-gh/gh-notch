import XCTest
@testable import gh_notch

final class TimerParsingTests: XCTestCase {

    // MARK: parseDuration

    func testAttachedUnits() {
        XCTAssertEqual(TimerParsing.parseDuration("10m"), 600)
        XCTAssertEqual(TimerParsing.parseDuration("1h30m"), 5400)
        XCTAssertEqual(TimerParsing.parseDuration("90s"), 90)
        XCTAssertEqual(TimerParsing.parseDuration("2h"), 7200)
    }

    func testBareIntegerIsMinutes() {
        XCTAssertEqual(TimerParsing.parseDuration("10"), 600)
    }

    func testSpacedNumberAndUnitWord() {
        XCTAssertEqual(TimerParsing.parseDuration("5 minutes"), 300)
        XCTAssertEqual(TimerParsing.parseDuration("1 hour 30 min"), 5400)
    }

    func testLongUnitForms() {
        XCTAssertEqual(TimerParsing.parseDuration("2 hours"), 7200)
        XCTAssertEqual(TimerParsing.parseDuration("30 sec"), 30)
    }

    func testInvalidDurations() {
        XCTAssertNil(TimerParsing.parseDuration("coffee"))
        XCTAssertNil(TimerParsing.parseDuration("10m coffee"))  // trailing non-duration
        XCTAssertNil(TimerParsing.parseDuration("5k"))          // unknown unit
        XCTAssertNil(TimerParsing.parseDuration(""))
    }

    func testClampsToMax() {
        XCTAssertEqual(TimerParsing.parseDuration("999999h"), TimerParsing.maxDuration)
        XCTAssertEqual(TimerParsing.parseDuration("25h"), TimerParsing.maxDuration)
    }

    // MARK: durationOfToken

    func testDurationOfTokenRejectsDanglingNumber() {
        XCTAssertNil(TimerParsing.durationOfToken("10m5"))  // number with no unit mid-token
        XCTAssertNil(TimerParsing.durationOfToken("abc"))
    }

    // MARK: parseTimerCommand

    func testCommandWithDurationAndLabel() {
        let r = TimerParsing.parseTimerCommand("timer 10m coffee")
        XCTAssertEqual(r?.duration, 600)
        XCTAssertEqual(r?.label, "coffee")
    }

    func testCommandMultiTokenDurationAndMultiWordLabel() {
        let r = TimerParsing.parseTimerCommand("timer 1h 30m tea time")
        XCTAssertEqual(r?.duration, 5400)
        XCTAssertEqual(r?.label, "tea time")
    }

    func testCommandBareMinutesNoLabel() {
        let r = TimerParsing.parseTimerCommand("timer 10")
        XCTAssertEqual(r?.duration, 600)
        XCTAssertNil(r?.label)
    }

    func testCommandSpacedUnitWithLabel() {
        let r = TimerParsing.parseTimerCommand("timer 5 minutes left")
        XCTAssertEqual(r?.duration, 300)
        XCTAssertEqual(r?.label, "left")
    }

    func testCommandIsCaseInsensitive() {
        XCTAssertEqual(TimerParsing.parseTimerCommand("Timer 45s")?.duration, 45)
    }

    func testCommandRejectsNonKeywordAndEmpty() {
        XCTAssertNil(TimerParsing.parseTimerCommand("timers"))       // must not fire on "timers"
        XCTAssertNil(TimerParsing.parseTimerCommand("timer"))        // keyword only
        XCTAssertNil(TimerParsing.parseTimerCommand("timer coffee")) // no duration
        XCTAssertNil(TimerParsing.parseTimerCommand("set an alarm"))
    }

    func testCommandClampsAndKeepsLabel() {
        let r = TimerParsing.parseTimerCommand("timer 25h nap")
        XCTAssertEqual(r?.duration, TimerParsing.maxDuration)
        XCTAssertEqual(r?.label, "nap")
    }
}
