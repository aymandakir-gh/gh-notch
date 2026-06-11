import Foundation
import IOKit.ps

/// Reads a `BatterySnapshot` from the system. Abstracted behind a protocol so the
/// monitor can be unit-tested with a stub (IOKit cannot run headlessly in CI).
protocol PowerSourceReading {
    func read() -> BatterySnapshot
}

/// Live reader backed by IOKit `IOPowerSources`.
struct IOKitPowerSourceReader: PowerSourceReading {

    func read() -> BatterySnapshot {
        guard
            let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
            let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef],
            let first = sources.first,
            let description = IOPSGetPowerSourceDescription(blob, first)?.takeUnretainedValue() as? [String: Any]
        else {
            return .noBattery
        }
        return Self.snapshot(from: description)
    }

    /// Map an IOKit power-source description dictionary to a `BatterySnapshot`.
    /// Exposed `internal` so tests can exercise the mapping with synthetic dicts.
    static func snapshot(from description: [String: Any]) -> BatterySnapshot {
        let maxCapacity = description[kIOPSMaxCapacityKey] as? Int ?? 0
        let currentCapacity = description[kIOPSCurrentCapacityKey] as? Int ?? 0
        let percent = maxCapacity > 0
            ? Int((Double(currentCapacity) / Double(maxCapacity) * 100).rounded())
            : currentCapacity

        let isCharging = description[kIOPSIsChargingKey] as? Bool ?? false
        let powerState = description[kIOPSPowerSourceStateKey] as? String
        let isPluggedIn = powerState == kIOPSACPowerValue

        // IOKit reports -1 while the estimate is still being computed.
        let rawTime: Int? = isCharging
            ? description[kIOPSTimeToFullChargeKey] as? Int
            : description[kIOPSTimeToEmptyKey] as? Int
        let minutesRemaining = rawTime.flatMap { $0 >= 0 ? $0 : nil }

        return BatterySnapshot(
            percent: min(max(percent, 0), 100),
            isCharging: isCharging,
            isPluggedIn: isPluggedIn,
            minutesRemaining: minutesRemaining,
            hasBattery: true
        )
    }
}
