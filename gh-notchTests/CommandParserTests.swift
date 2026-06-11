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
}
