import Foundation

/// Source of calendar data, abstracted behind a protocol so `CalendarModel` can be
/// unit-tested with a fake (EventKit can't run headlessly in CI). The real
/// implementation is `EventKitCalendarService`.
protocol CalendarService {
    /// Current read authorization.
    var authorization: CalendarPermission { get }
    /// Prompt for access (no-op if already decided); returns the resulting state.
    func requestAccess() async -> CalendarPermission
    /// Events overlapping the day that contains `day`. Empty unless granted.
    func events(for day: Date) -> [CalendarEvent]
}

/// In-memory `CalendarService` for unit tests and SwiftUI previews. A class so
/// `requestAccess()` can flip `authorization` the way the real EventKit store does
/// once the user responds.
final class FakeCalendarService: CalendarService {
    private(set) var authorization: CalendarPermission
    var events: [CalendarEvent]
    /// Number of times `requestAccess()` actually prompted — asserted in tests.
    private(set) var requestCount = 0

    private let resolvedPermission: CalendarPermission

    /// - Parameters:
    ///   - authorization: starting authorization state.
    ///   - events: events returned by `events(for:)`.
    ///   - resolvesTo: state `requestAccess()` settles on (defaults to `authorization`).
    init(
        authorization: CalendarPermission = .granted,
        events: [CalendarEvent] = [],
        resolvesTo: CalendarPermission? = nil
    ) {
        self.authorization = authorization
        self.events = events
        self.resolvedPermission = resolvesTo ?? authorization
    }

    func requestAccess() async -> CalendarPermission {
        requestCount += 1
        authorization = resolvedPermission
        return authorization
    }

    func events(for day: Date) -> [CalendarEvent] {
        authorization == .granted ? events : []
    }
}
