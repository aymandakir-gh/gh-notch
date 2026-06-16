import XCTest
@testable import gh_notch

@MainActor
final class CalendarModelTests: XCTestCase {

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

    private func todaysEvents(_ cal: Calendar, now: Date) throws -> [CalendarEvent] {
        [
            CalendarEvent(id: "2", title: "Design",
                          start: try date(cal, 2026, 6, 16, 14, 30),
                          end: try date(cal, 2026, 6, 16, 15, 30), isAllDay: false),
            CalendarEvent(id: "1", title: "Standup",
                          start: try date(cal, 2026, 6, 16, 9, 0),
                          end: try date(cal, 2026, 6, 16, 10, 0), isAllDay: false),
            CalendarEvent(id: "6", title: "Holiday",
                          start: cal.startOfDay(for: now),
                          end: try date(cal, 2026, 6, 17, 0, 0), isAllDay: true)
        ]
    }

    func testPermissionReflectsServiceOnInit() {
        let model = CalendarModel(service: FakeCalendarService(authorization: .denied))
        XCTAssertEqual(model.permission, .denied)
    }

    func testRefreshLoadsSortedAgendaWhenGranted() async throws {
        let cal = try romeCalendar()
        let now = try date(cal, 2026, 6, 16, 10, 0)
        let model = CalendarModel(
            service: FakeCalendarService(authorization: .granted, events: try todaysEvents(cal, now: now)),
            calendar: cal, now: { now }
        )
        await model.refresh()
        XCTAssertEqual(model.agenda.map(\.title), ["Holiday", "Standup", "Design"])
        XCTAssertEqual(model.nextEvent?.title, "Design")
    }

    func testRefreshClearsAgendaWhenDenied() async throws {
        let cal = try romeCalendar()
        let now = try date(cal, 2026, 6, 16, 10, 0)
        let model = CalendarModel(
            service: FakeCalendarService(authorization: .denied, events: try todaysEvents(cal, now: now)),
            calendar: cal, now: { now }
        )
        await model.refresh()
        XCTAssertTrue(model.agenda.isEmpty)
        XCTAssertNil(model.nextEvent)
        XCTAssertEqual(model.permission, .denied)
    }

    func testRequestAccessClearsTheInFlightFlagWhenDone() async {
        let fake = FakeCalendarService(authorization: .notDetermined, resolvesTo: .granted)
        let model = CalendarModel(service: fake)
        await model.requestAccess()
        XCTAssertFalse(model.isRequestingAccess)
        XCTAssertEqual(model.permission, .granted)
    }

    func testRequestAccessPromptsOnceWhenNotDetermined() async throws {
        let cal = try romeCalendar()
        let now = try date(cal, 2026, 6, 16, 10, 0)
        let fake = FakeCalendarService(
            authorization: .notDetermined, events: try todaysEvents(cal, now: now), resolvesTo: .granted
        )
        let model = CalendarModel(service: fake, calendar: cal, now: { now })
        await model.requestAccess()
        XCTAssertEqual(model.permission, .granted)
        XCTAssertEqual(fake.requestCount, 1)
        XCTAssertEqual(model.agenda.map(\.title), ["Holiday", "Standup", "Design"])
    }

    func testRequestAccessDoesNotPromptWhenAlreadyGranted() async {
        let fake = FakeCalendarService(authorization: .granted, events: [])
        let model = CalendarModel(service: fake)
        await model.requestAccess()
        XCTAssertEqual(fake.requestCount, 0)
        XCTAssertEqual(model.permission, .granted)
    }

    func testRequestAccessDoesNotPromptWhenDenied() async {
        let fake = FakeCalendarService(authorization: .denied)
        let model = CalendarModel(service: fake)
        await model.requestAccess()
        XCTAssertEqual(fake.requestCount, 0)
        XCTAssertEqual(model.permission, .denied)
    }
}
