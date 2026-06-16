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
        func countdown(_ startOffset: TimeInterval) -> String {
            CalendarFormatting.relative(start: offset(startOffset), end: offset(startOffset + 3600),
                                        isAllDay: false, now: now)
        }
        XCTAssertEqual(countdown(30), "in <1m")
        XCTAssertEqual(countdown(900), "in 15m")
        XCTAssertEqual(countdown(3600), "in 1h")
        XCTAssertEqual(countdown(3900), "in 1h 5m")
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
        // Assert the 12-hour behaviour without pinning the AM/PM separator, which
        // ICU renders with a narrow no-break space (U+202F) on newer OSes.
        let rome = try XCTUnwrap(TimeZone(identifier: "Europe/Rome"))
        let text = CalendarFormatting.time(try romeInstant(), locale: Locale(identifier: "en_US"), timeZone: rome)
        XCTAssertTrue(text.contains("2:30"), text)
        XCTAssertTrue(text.uppercased().contains("PM"), text)
    }

    func testTimeRespectsTimeZone() throws {
        // The same instant rendered in Los Angeles is nine hours earlier than Rome.
        let rome = try XCTUnwrap(TimeZone(identifier: "Europe/Rome"))
        let la = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        let instant = try romeInstant()
        let romeText = CalendarFormatting.time(instant, locale: Locale(identifier: "en_US"), timeZone: rome)
        let laText = CalendarFormatting.time(instant, locale: Locale(identifier: "en_US"), timeZone: la)
        XCTAssertTrue(laText.contains("5:30"), laText)
        XCTAssertNotEqual(romeText, laText)
    }
}
