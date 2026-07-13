import EventKit
import Foundation
import Observation

/// Observable calendar state for the notch UI: current permission and today's
/// agenda, with the next upcoming event derived on demand. Mirrors `BatteryMonitor`
/// (injected service, polled refresh) but adds an async, lazily-triggered access
/// request so the permission prompt only appears when the user opens the panel —
/// never at launch.
@Observable
@MainActor
final class CalendarModel {

    private(set) var permission: CalendarPermission
    private(set) var agenda: [CalendarEvent] = []
    /// True while the system access prompt is up, so the panel can stay open
    /// instead of auto-collapsing out from under the dialog.
    private(set) var isRequestingAccess = false

    @ObservationIgnored private let service: CalendarService
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var storeObserver: NSObjectProtocol?

    init(
        service: CalendarService = EventKitCalendarService(),
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.service = service
        self.calendar = calendar
        self.now = now
        self.permission = service.authorization
    }

    // No deinit: these models are @State-owned for the app's lifetime, so dropping
    // the timer cleanup avoids a nonisolated deinit touching MainActor state (a
    // Swift 6 / strict-concurrency error). stop() handles teardown when needed.

    /// Earliest timed event today that hasn't ended (drives the collapsed chip).
    var nextEvent: CalendarEvent? {
        CalendarLogic.nextEvent(agenda, now: now())
    }

    /// Re-read authorization (catches changes made in System Settings) and load
    /// today's agenda when granted. Never prompts — safe on appear and on a timer.
    /// The EventKit fetch is awaited off the main actor; `now` is sampled once so
    /// the fetch window and the filter window can't disagree across a midnight tick.
    func refresh() async {
        permission = service.authorization
        guard permission == .granted else {
            agenda = []
            return
        }
        let reference = now()
        let events = await service.events(for: reference)
        agenda = CalendarLogic.agenda(from: events, now: reference, calendar: calendar)
    }

    /// Initial refresh, event-driven updates on any calendar-store change, plus
    /// a low-frequency poll so relative times stay current. Does NOT prompt.
    func start() {
        Task { await refresh() }
        if storeObserver == nil {
            storeObserver = NotificationCenter.default.addObserver(
                forName: .EKEventStoreChanged,
                object: nil,
                queue: .main
            ) { _ in
                Task { @MainActor [weak self] in await self?.refresh() }
            }
        }
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in await self?.refresh() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        if let storeObserver {
            NotificationCenter.default.removeObserver(storeObserver)
        }
        storeObserver = nil
        timer?.invalidate()
        timer = nil
    }

    /// Request access only if the user hasn't decided yet, then refresh. Call when
    /// the feature becomes visible (panel expanded) — lazy permission, not at launch.
    func requestAccess() async {
        if permission == .notDetermined {
            isRequestingAccess = true
            permission = await service.requestAccess()
            isRequestingAccess = false
        }
        await refresh()
    }
}
