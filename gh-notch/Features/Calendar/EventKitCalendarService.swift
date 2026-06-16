import EventKit
import Foundation

/// Live `CalendarService` backed by EventKit. Deliberately thin: it maps EventKit
/// types to the app's pure value types and does nothing else, so the testable
/// logic all lives in `CalendarLogic` / `CalendarFormatting`. This file is the one
/// piece CI compiles but cannot exercise headlessly (no calendar store / TCC in CI).
struct EventKitCalendarService: CalendarService {
    private let store = EKEventStore()

    var authorization: CalendarPermission {
        CalendarPermission(EKEventStore.authorizationStatus(for: .event))
    }

    func requestAccess() async -> CalendarPermission {
        _ = try? await store.requestFullAccessToEvents()
        return authorization
    }

    func events(for day: Date) -> [CalendarEvent] {
        guard authorization == .granted else { return [] }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate).map { CalendarEvent(from: $0) }
    }
}

extension CalendarPermission {
    /// Collapse EventKit's authorization status to the three states the UI uses.
    /// `.authorized` is the legacy (pre-macOS 14) granted value; `.fullAccess` is
    /// its macOS 14 replacement. `.writeOnly` maps to denied — the feature reads.
    init(_ status: EKAuthorizationStatus) {
        switch status {
        case .notDetermined:
            self = .notDetermined
        case .fullAccess, .authorized:
            self = .granted
        case .denied, .restricted, .writeOnly:
            self = .denied
        @unknown default:
            self = .denied
        }
    }
}

extension CalendarEvent {
    /// Map an `EKEvent` to the pure value type, defaulting any missing fields so we
    /// never force-unwrap EventKit's implicitly-unwrapped optionals.
    init(from event: EKEvent) {
        self.init(
            id: event.eventIdentifier ?? UUID().uuidString,
            title: event.title ?? "(No title)",
            start: event.startDate ?? .distantPast,
            end: event.endDate ?? .distantFuture,
            isAllDay: event.isAllDay
        )
    }
}
