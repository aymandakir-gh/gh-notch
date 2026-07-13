import Foundation
import Observation

/// Observable clock: current time + localized date, ticking each second while
/// started. Injectable clock for tests.
@Observable
@MainActor
final class ClockModel {

    private(set) var now: Date

    @ObservationIgnored private let clock: () -> Date
    @ObservationIgnored private var timer: Timer?

    init(clock: @escaping () -> Date = Date.init) {
        self.clock = clock
        self.now = clock()
    }

    // No deinit cleanup: app-lifetime model, stop() tears down (see
    // CalendarModel for the strict-concurrency rationale).

    /// Begin ticking.
    func start() {
        guard timer == nil else { return }
        tick()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// Stop ticking.
    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        now = clock()
    }

    var timeText: String { ClockModel.timeFormatter.string(from: now) }
    var dateText: String { ClockModel.dateFormatter.string(from: now) }

    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("HHmm")
        return formatter
    }()

    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEEEdMMMM")
        return formatter
    }()
}
