import Foundation

/// Pure, deterministic formatting for calendar events. Every function takes its
/// `now`/`locale`/`timeZone` explicitly, so output is testable without touching
/// the system clock or locale.
enum CalendarFormatting {

    /// Relative status of an event: "now", "ended", "all day", or a countdown
    /// like "in 15m" / "in 1h" / "in 1h 5m" / "in <1m".
    static func relative(start: Date, end: Date, isAllDay: Bool, now: Date) -> String {
        if isAllDay { return "all day" }
        if now >= end { return "ended" }
        if now >= start { return "now" }

        let minutes = Int(start.timeIntervalSince(now) / 60)
        if minutes < 1 { return "in <1m" }
        if minutes < 60 { return "in \(minutes)m" }
        let hours = minutes / 60
        let remainder = minutes % 60
        return remainder == 0 ? "in \(hours)h" : "in \(hours)h \(remainder)m"
    }

    static func relative(for event: CalendarEvent, now: Date) -> String {
        relative(start: event.start, end: event.end, isAllDay: event.isAllDay, now: now)
    }

    /// Compact form for the tight collapsed bar — drops the leading "in ".
    static func compact(for event: CalendarEvent, now: Date) -> String {
        let full = relative(for: event, now: now)
        return full.hasPrefix("in ") ? String(full.dropFirst(3)) : full
    }

    /// Localized time-of-day, e.g. "14:30" under a 24-hour locale (en_IT) or
    /// "2:30 PM" under a 12-hour one (en_US). Uses the "jmm" template so the
    /// hour cycle follows the locale.
    static func time(_ date: Date, locale: Locale, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate("jmm")
        return formatter.string(from: date)
    }
}
