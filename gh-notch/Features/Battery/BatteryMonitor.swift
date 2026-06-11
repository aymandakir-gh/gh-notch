import Foundation
import Observation

/// Observable battery state, polled on an interval.
///
/// IOKit also exposes a run-loop notification source for power changes, but a
/// short poll is simpler, dependency-light, and accurate enough for a HUD. The
/// reader is injected so the poll logic is unit-testable without hardware.
@Observable
final class BatteryMonitor {

    private(set) var snapshot: BatterySnapshot

    @ObservationIgnored private let reader: PowerSourceReading
    @ObservationIgnored private let interval: TimeInterval
    @ObservationIgnored private var timer: Timer?

    init(reader: PowerSourceReading = IOKitPowerSourceReader(), interval: TimeInterval = 30) {
        self.reader = reader
        self.interval = interval
        self.snapshot = reader.read()
    }

    deinit {
        timer?.invalidate()
    }

    /// Take a reading immediately. Safe to call from the main thread.
    func refresh() {
        snapshot = reader.read()
    }

    /// Begin periodic polling. Called when the panel appears.
    func start() {
        guard timer == nil else { return }
        refresh()
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// Stop polling. Called when the panel disappears.
    func stop() {
        timer?.invalidate()
        timer = nil
    }
}
