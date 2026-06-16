import XCTest
@testable import gh_notch

final class CommandParserTests: XCTestCase {

    private let parser = CommandParser()

    func testEmptyInputReturnsNil() {
        XCTAssertNil(parser.parse(""))
        XCTAssertNil(parser.parse("   "))
    }

    func testMathIsHandledLocally() {
        let result = parser.parse("2 + 2 * 3")
        XCTAssertEqual(result?.output, "8")
        XCTAssertEqual(result?.handledLocally, true)
    }

    func testWordCount() {
        let result = parser.parse("count the quick brown fox")
        XCTAssertEqual(result?.output, "4 words · 19 characters")
        XCTAssertEqual(result?.handledLocally, true)
    }

    func testWordCountShortAlias() {
        XCTAssertEqual(parser.parse("wc hello world")?.output, "2 words · 11 characters")
    }

    func testUpperAndLower() {
        XCTAssertEqual(parser.parse("upper hello")?.output, "HELLO")
        XCTAssertEqual(parser.parse("lower HELLO")?.output, "hello")
    }

    func testHelp() {
        let result = parser.parse("help")
        XCTAssertEqual(result?.handledLocally, true)
        XCTAssertTrue(result?.output.contains("math") ?? false)
    }

    func testDateUsesInjectedClock() {
        let fixed = Date(timeIntervalSince1970: 0)
        let clockParser = CommandParser(now: { fixed })
        let result = clockParser.parse("date")
        XCTAssertEqual(result?.handledLocally, true)
        XCTAssertFalse(result?.output.isEmpty ?? true)
    }

    func testUnrecognizedFallsBackToRemote() {
        let result = parser.parse("what is the capital of France")
        XCTAssertEqual(result?.handledLocally, false)
        XCTAssertTrue(result?.output.contains("Settings") ?? false)
    }

    func testReverse() {
        let result = parser.parse("reverse abcde")
        XCTAssertEqual(result?.output, "edcba")
        XCTAssertEqual(result?.handledLocally, true)
    }

    func testBase64RoundTrip() {
        XCTAssertEqual(parser.parse("base64 hello")?.output, "aGVsbG8=")
        XCTAssertEqual(parser.parse("unbase64 aGVsbG8=")?.output, "hello")
    }

    func testInvalidBase64() {
        let result = parser.parse("unbase64 !!!not-valid")
        XCTAssertEqual(result?.output, "Invalid base64")
        XCTAssertEqual(result?.handledLocally, true)
    }

    func testUnbase64ValidButNonUTF8() {
        // "/w==" is valid base64 (one 0xFF byte) but not valid UTF-8.
        let result = parser.parse("unbase64 /w==")
        XCTAssertEqual(result?.output, "Decoded bytes are not valid UTF-8")
        XCTAssertEqual(result?.handledLocally, true)
    }

    func testPercentage() {
        XCTAssertEqual(parser.parse("20% of 80")?.output, "16")
        XCTAssertEqual(parser.parse("12.5% of 200")?.output, "25")
        XCTAssertEqual(parser.parse("20% of 80")?.handledLocally, true)
    }

    func testPercentageDoesNotSwallowNaturalLanguage() {
        // "… of …" without a percentage must still fall through to remote.
        XCTAssertEqual(parser.parse("capital of France")?.handledLocally, false)
    }

    func testPercentageRejectsNonDecimalOperands() {
        // Scientific/hex-float literals and inf/nan must NOT compute locally —
        // they fall through to the AI endpoint instead of surprising results.
        XCTAssertEqual(parser.parse("1e3% of 2")?.handledLocally, false)
        XCTAssertEqual(parser.parse("0x1p4% of 2")?.handledLocally, false)
        XCTAssertEqual(parser.parse("inf% of 80")?.handledLocally, false)
        XCTAssertEqual(parser.parse("nan% of 10")?.handledLocally, false)
    }

    func testFractionalResultUsesPeriodSeparator() {
        // Output must use '.' regardless of system locale so it round-trips back
        // into the parser (which reads numbers locale-independently).
        XCTAssertEqual(CommandParser.format(0.32), "0.32")
        XCTAssertEqual(parser.parse("7% of 80")?.output, "5.6")
    }
}
