import SwiftUI

/// Compact battery indicator: SF Symbol that reflects level + charging state,
/// the percentage, and a time estimate when macOS provides one. Content-sized so
/// the parent controls layout.
struct BatteryView: View {
    @Bindable var monitor: BatteryMonitor

    var body: some View {
        let snapshot = monitor.snapshot

        HStack(spacing: 6) {
            Image(systemName: symbolName(for: snapshot))
                .font(.system(size: 15))
                .foregroundStyle(tint(for: snapshot))
                .symbolRenderingMode(.hierarchical)

            if snapshot.hasBattery {
                Text("\(snapshot.percent)%")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
            } else {
                Text("No battery")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func symbolName(for snapshot: BatterySnapshot) -> String {
        guard snapshot.hasBattery else { return "powerplug" }
        if snapshot.isCharging { return "battery.100percent.bolt" }
        switch snapshot.percent {
        case ..<10: return "battery.0percent"
        case ..<35: return "battery.25percent"
        case ..<60: return "battery.50percent"
        case ..<85: return "battery.75percent"
        default: return "battery.100percent"
        }
    }

    private func tint(for snapshot: BatterySnapshot) -> Color {
        if snapshot.isCharging || snapshot.isPluggedIn { return .green }
        if snapshot.hasBattery && snapshot.percent <= 10 { return .red }
        return .primary
    }
}

#Preview {
    BatteryView(monitor: BatteryMonitor())
        .padding()
        .background(Color.black)
}
