import XCTest
@testable import gh_notch

final class CalendarLogicTests: XCTestCase {

    // MARK: - Fixtures (Europe/Rome so day-windowing is timezone-exercised)

    private func romeCalendar() throws -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/Rome"))
        return calendar
    }

    private func date(_ calendar: Calendar, _ year: Int, _ month: Int, _ day: Int,
                      _ hour: Int, _ minute: Int) throws -> Date {
        try XCTUnwrap(calendar.date(from: DateComponents(
            year: year, month: month, day: day, hour: hour, minute: minute
        )))
    }

    private func event(_ id: String, _ title: String, _ start: Date, _ end: Date,
                       allDay: Bool = false) -> CalendarEvent {
        CalendarEvent(id: id, title: title, start: start, end: end, isAllDay: allDay)
    }

    // MARK: - Agenda

    func testAgendaKeepsTodaysEventsSortedAllDayFirst() throws {
        let cal = try romeCalendar()
        let now = try date(cal, 2026, 6, 16, 10, 0)
        let standup = event("1", "Standup", try date(cal, 2026, 6, 16, 9, 0), try date(cal, 2026, 6, 16, 10, 0))
        let design = event("2", "Design", try date(cal, 2026, 6, 16, 14, 30), try date(cal, 2026, 6, 16, 15, 30))
        let late = event("3", "Late", try date(cal, 2026, 6, 16, 23, 30), try date(cal, 2026, 6, 16, 23, 45))
        let yesterday = event("4", "Yesterday", try date(cal, 2026, 6, 15, 12, 0), try date(cal, 2026, 6, 15, 13, 0))
        let tomorrow = event("5", "Tomorrow", try date(cal, 2026, 6, 17, 9, 0), try date(cal, 2026, 6, 17, 10, 0))
        let holiday = event("6", "Holiday", cal.startOfDay(for: now), try date(cal, 2026, 6, 17, 0, 0), allDay: true)

        let agenda = CalendarLogic.agenda(
            from: [tomorrow, late, standup, holiday, yesterday, design],
            now: now, calendar: cal
        )

        // All-day first, then by start; yesterday/tomorrow excluded.
        XCTAssertEqual(agenda.map(\.title), ["Holiday", "Standup", "Design", "Late"])
    }

    func testAgendaIncludesLateNightEventInLocalTimezone() throws {
        // 23:30 in Rome is still "today" — proves the day window uses the
        // calendar's timezone, not UTC.
        let cal = try romeCalendar()
        let now = try date(cal, 2026, 6, 16, 8, 0)
        let late = event("1", "Late", try date(cal, 2026, 6, 16, 23, 30), try date(cal, 2026, 6, 16, 23, 45))
        let agenda = CalendarLogic.agenda(from: [late], now: now, calendar: cal)
        XCTAssertEqual(agenda.map(\.id), ["1"])
    }

    func testAgendaEmptyWhenNothingToday() throws {
        let cal = try romeCalendar()
        let now = try date(cal, 2026, 6, 16, 10, 0)
        let yesterday = event("1", "Y", try date(cal, 2026, 6, 15, 12, 0), try date(cal, 2026, 6, 15, 13, 0))
        XCTAssertTrue(CalendarLogic.agenda(from: [yesterday], now: now, calendar: cal).isEmpty)
    }

    // MARK: - Sorting

    func testSortedBreaksStartTiesByTitle() throws {
        let cal = try romeCalendar()
        let start = try date(cal, 2026, 6, 16, 9, 0)
        let end = try date(cal, 2026, 6, 16, 10, 0)
        let beta = event("b", "Beta", start, end)
        let alpha = event("a", "Alpha", start, end)
        XCTAssertEqual(CalendarLogic.sorted([beta, alpha]).map(\.title), ["Alpha", "Beta"])
    }

    // MARK: - Next event

    func testNextEventSkipsAllDayAndEndedPicksEarliest() throws {
        let cal = try romeCalendar()
        let now = try date(cal, 2026, 6, 16, 10, 0)
        let ended = event("1", "Standup", try date(cal, 2026, 6, 16, 9, 0), try date(cal, 2026, 6, 16, 10, 0))
        let design = event("2", "Design", try date(cal, 2026, 6, 16, 14, 30), try date(cal, 2026, 6, 16, 15, 30))
        let late = event("3", "Late", try date(cal, 2026, 6, 16, 23, 30), try date(cal, 2026, 6, 16, 23, 45))
        let holiday = event("6", "Holiday", cal.startOfDay(for: now), try date(cal, 2026, 6, 17, 0, 0), allDay: true)

        let next = CalendarLogic.nextEvent([holiday, ended, late, design], now: now)
        XCTAssertEqual(next?.id, "2")
    }

    func testNextEventCountsAnOngoingEvent() throws {
        let cal = try romeCalendar()
        let now = try date(cal, 2026, 6, 16, 10, 0)
        let ongoing = event("1", "Now", try date(cal, 2026, 6, 16, 9, 30), try date(cal, 2026, 6, 16, 10, 30))
        XCTAssertEqual(CalendarLogic.nextEvent([ongoing], now: now)?.id, "1")
    }

    func testNextEventNilWhenAllEnded() throws {
        let cal = try romeCalendar()
        let now = try date(cal, 2026, 6, 16, 18, 0)
        let ended = event("1", "Done", try date(cal, 2026, 6, 16, 9, 0), try date(cal, 2026, 6, 16, 10, 0))
        XCTAssertNil(CalendarLogic.nextEvent([ended], now: now))
    }
}
