import Foundation

/// Pure derivation over `CalendarEvent`s: day-windowing (timezone-aware via the
/// injected `Calendar`), sorting, and next-event selection. No EventKit, no
/// global clock — every entry point takes its `now`/`calendar` explicitly so the
/// behaviour is deterministic and fully unit-testable.
enum CalendarLogic {

    /// Start (inclusive) and end (exclusive) of the day that contains `date`, in
    /// the calendar's timezone. `nil` only if date math fails (never in practice).
    static func dayBounds(containing date: Date, calendar: Calendar) -> (start: Date, end: Date)? {
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return nil }
        return (start, end)
    }

    /// Today's agenda: events overlapping the day that contains `now` (in the
    /// calendar's timezone), sorted for display.
    static func agenda(from events: [CalendarEvent], now: Date, calendar: Calendar) -> [CalendarEvent] {
        guard let bounds = dayBounds(containing: now, calendar: calendar) else { return [] }
        let today = events.filter { $0.start < bounds.end && $0.end > bounds.start }
        return sorted(today)
    }

    /// Display order: all-day events first, then by start time, then title (a
    /// stable tiebreak so the order is deterministic for tests).
    static func sorted(_ events: [CalendarEvent]) -> [CalendarEvent] {
        events.sorted { lhs, rhs in
            if lhs.isAllDay != rhs.isAllDay { return lhs.isAllDay }
            if lhs.start != rhs.start { return lhs.start < rhs.start }
            return lhs.title < rhs.title
        }
    }

    /// The collapsed bar's "next event": the earliest timed event that has not yet
    /// ended. All-day events are excluded — they aren't a time to count down to.
    static func nextEvent(_ events: [CalendarEvent], now: Date) -> CalendarEvent? {
        events
            .filter { !$0.isAllDay && $0.end > now }
            .min { $0.start < $1.start }
    }
}
