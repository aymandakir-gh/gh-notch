import XCTest
@testable import gh_notch

final class CalendarFormattingTests: XCTestCase {

    private let now = Date(timeIntervalSinceReferenceDate: 1_000_000)

    private func offset(_ seconds: TimeInterval) -> Date {
        now.addingTimeInterval(seconds)
    }

    // MARK: - Relative

    func testRelativeAllDay() {
        XCTAssertEqual(
            CalendarFormatting.relative(start: offset(-3600), end: offset(3600), isAllDay: true, now: now),
            "all day"
        )
    }

    func testRelativeEnded() {
        XCTAssertEqual(
            CalendarFormatting.relative(start: offset(-7200), end: offset(-3600), isAllDay: false, now: now),
            "ended"
        )
    }

    func testRelativeNowWhileOngoing() {
        XCTAssertEqual(
            CalendarFormatting.relative(start: offset(-60), end: offset(60), isAllDay: false, now: now),
            "now"
        )
    }

    func testRelativeCountdownVariants() {
        XCTAssertEqual(CalendarFormatting.relative(start: offset(30), end: offset(3600), isAllDay: false, now: now), "in <1m")
        XCTAssertEqual(CalendarFormatting.relative(start: offset(900), end: offset(4500), isAllDay: false, now: now), "in 15m")
        XCTAssertEqual(CalendarFormatting.relative(start: offset(3600), end: offset(7200), isAllDay: false, now: now), "in 1h")
        XCTAssertEqual(CalendarFormatting.relative(start: offset(3900), end: offset(7200), isAllDay: false, now: now), "in 1h 5m")
    }

    func testCompactDropsInPrefix() {
        let soon = CalendarEvent(id: "1", title: "x", start: offset(900), end: offset(4500), isAllDay: false)
        let ongoing = CalendarEvent(id: "2", title: "y", start: offset(-60), end: offset(60), isAllDay: false)
        XCTAssertEqual(CalendarFormatting.compact(for: soon, now: now), "15m")
        XCTAssertEqual(CalendarFormatting.compact(for: ongoing, now: now), "now")
    }

    // MARK: - Time of day (locale + timezone)

    private func romeInstant() throws -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/Rome"))
        return try XCTUnwrap(cal.date(from: DateComponents(year: 2026, month: 6, day: 16, hour: 14, minute: 30)))
    }

    func testTimeIs24HourUnderItalianLocale() throws {
        let rome = try XCTUnwrap(TimeZone(identifier: "Europe/Rome"))
        XCTAssertEqual(
            CalendarFormatting.time(try romeInstant(), locale: Locale(identifier: "en_IT"), timeZone: rome),
            "14:30"
        )
    }

    func testTimeIs12HourUnderUSLocale() throws {
        let rome = try XCTUnwrap(TimeZone(identifier: "Europe/Rome"))
        XCTAssertEqual(
            CalendarFormatting.time(try romeInstant(), locale: Locale(identifier: "en_US"), timeZone: rome),
            "2:30 PM"
        )
    }

    func testTimeRespectsTimeZone() throws {
        // The same instant rendered in Los Angeles is nine hours earlier.
        let la = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        XCTAssertEqual(
            CalendarFormatting.time(try romeInstant(), locale: Locale(identifier: "en_US"), timeZone: la),
            "5:30 AM"
        )
    }
}
