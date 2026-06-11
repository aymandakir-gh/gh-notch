import Foundation

/// A point-in-time reading of the system battery.
struct BatterySnapshot: Equatable {
    /// Charge level, 0...100.
    let percent: Int
    /// Whether the battery is actively charging.
    let isCharging: Bool
    /// Whether the machine is on AC power.
    let isPluggedIn: Bool
    /// Minutes until empty (on battery) or full (charging). `nil` while macOS is
    /// still estimating, or when there is no battery (desktop).
    let minutesRemaining: Int?

    /// Whether the host has a battery at all. Desktops report `false`.
    let hasBattery: Bool

    /// Snapshot for a machine with no battery (Mac mini / Studio / external use).
    static let noBattery = BatterySnapshot(
        percent: 100,
        isCharging: false,
        isPluggedIn: true,
        minutesRemaining: nil,
        hasBattery: false
    )

    /// Human-readable time estimate, e.g. "1:25 left" / "0:40 to full".
    var timeDescription: String? {
        guard hasBattery, let minutes = minutesRemaining, minutes > 0 else { return nil }
        let hours = minutes / 60
        let mins = minutes % 60
        let clock = String(format: "%d:%02d", hours, mins)
        return isCharging ? "\(clock) to full" : "\(clock) left"
    }
}
