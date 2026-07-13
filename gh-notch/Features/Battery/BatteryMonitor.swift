import Foundation
import IOKit.ps
import Observation

/// Observable battery state, event-driven.
///
/// IOKit's power-source notification fires on plug/unplug, capacity ticks, and
/// low-power-mode changes — no more 30s polling burning wakeups while idle
/// (docs/PARITY-ROADMAP.md §2.6). A slow fallback poll (default 5 min) keeps
/// time-remaining estimates honest between events. The reader is injected so
/// the logic stays unit-testable without hardware.
@Observable
@MainActor
final class BatteryMonitor {

    private(set) var snapshot: BatterySnapshot

    @ObservationIgnored private let reader: PowerSourceReading
    @ObservationIgnored private let interval: TimeInterval
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var runLoopSource: CFRunLoopSource?

    init(reader: PowerSourceReading = IOKitPowerSourceReader(), interval: TimeInterval = 300) {
        self.reader = reader
        self.interval = interval
        self.snapshot = reader.read()
    }

    // No deinit cleanup: the model is app-lifetime (owned by PanelManager);
    // stop() tears down, and a nonisolated deinit touching MainActor state
    // would be a strict-concurrency error (same rationale as CalendarModel).

    /// Take a reading immediately. Safe to call from the main thread.
    func refresh() {
        snapshot = reader.read()
    }

    /// Start listening for power-source changes (plus the fallback poll).
    func start() {
        guard runLoopSource == nil, timer == nil else { return }
        refresh()

        // The C callback context carries `self` unretained: the monitor is
        // app-lifetime and stop() removes the source before any teardown.
        let context = Unmanaged.passUnretained(self).toOpaque()
        if let source = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            let monitor = Unmanaged<BatteryMonitor>.fromOpaque(context).takeUnretainedValue()
            // The source is scheduled on the main run loop.
            MainActor.assumeIsolated {
                monitor.refresh()
            }
        }, context)?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
            runLoopSource = source
        }

        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// Stop listening and polling.
    func stop() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        runLoopSource = nil
        timer?.invalidate()
        timer = nil
    }
}
