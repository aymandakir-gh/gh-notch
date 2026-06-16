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

    @ObservationIgnored private let service: CalendarService
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var timer: Timer?

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

    deinit {
        timer?.invalidate()
    }

    /// Earliest timed event today that hasn't ended (drives the collapsed chip).
    var nextEvent: CalendarEvent? {
        CalendarLogic.nextEvent(agenda, now: now())
    }

    /// Re-read authorization (catches changes made in System Settings) and load
    /// today's agenda when granted. Never prompts — safe on appear and on a timer.
    func refresh() {
        permission = service.authorization
        guard permission == .granted else {
            agenda = []
            return
        }
        agenda = CalendarLogic.agenda(from: service.events(for: now()), now: now(), calendar: calendar)
    }

    /// Initial refresh plus a low-frequency poll so relative times and newly added
    /// events stay current. Does NOT prompt for access.
    func start() {
        refresh()
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            // The timer fires on the main run loop, so MainActor isolation holds.
            MainActor.assumeIsolated { self?.refresh() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Request access only if the user hasn't decided yet, then refresh. Call when
    /// the feature becomes visible (panel expanded) — lazy permission, not at launch.
    func requestAccess() async {
        if permission == .notDetermined {
            permission = await service.requestAccess()
        }
        refresh()
    }
}
