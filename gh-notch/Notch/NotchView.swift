import SwiftUI

/// SwiftUI root rendered inside the notch panel.
///
/// Collapsed: a small always-visible status strip just below the notch (time +
/// battery) — so the app is discoverable and there's a clear click target.
/// Expanded: a compact panel with the AI command bar + clock/date + battery +
/// Settings. Opens on hover or click of the notch header; closes on Esc or a
/// click outside (handled by the panel). Hover only ever *opens* — there is no
/// hover-to-close, which was the source of the stuck-open bug.
struct NotchView: View {
    @Bindable var viewModel: NotchViewModel
    @State private var commandBar = CommandBarViewModel()
    @State private var battery = BatteryMonitor()
    @State private var clock = ClockModel()

    var body: some View {
        VStack(spacing: 0) {
            header
            if viewModel.isExpanded {
                expandedSurface
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(panelShape)
        .onAppear {
            battery.start()
            clock.start()
        }
        .animation(.easeOut(duration: 0.22), value: viewModel.isExpanded)
    }

    private var notchHeight: CGFloat {
        viewModel.geometry?.notchHeight ?? NotchGeometry.fallbackHeight
    }

    // MARK: - Header (notch blend + collapsed status strip) — the open/close target

    private var header: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: notchHeight) // blends with the camera/notch
            if !viewModel.isExpanded {
                collapsedStrip
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { viewModel.toggle() }
        .onHover { hovering in
            if hovering { viewModel.expand() }
        }
    }

    private var collapsedStrip: some View {
        HStack(spacing: 8) {
            Text(clock.timeText)
                .font(.system(size: 11, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.92))
            Spacer(minLength: 6)
            Image(systemName: collapsedBatterySymbol)
                .font(.system(size: 11))
                .foregroundStyle(collapsedBatteryTint)
                .symbolRenderingMode(.hierarchical)
            Text("\(battery.snapshot.percent)%")
                .font(.system(size: 10, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(.horizontal, 12)
        .frame(height: viewModel.collapsedReveal)
    }

    private var collapsedBatterySymbol: String {
        let snapshot = battery.snapshot
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

    private var collapsedBatteryTint: Color {
        let snapshot = battery.snapshot
        if snapshot.isCharging || snapshot.isPluggedIn { return .green }
        if snapshot.hasBattery && snapshot.percent <= 10 { return .red }
        return .white.opacity(0.85)
    }

    // MARK: - Expanded (command bar + clock/date + battery + settings)

    private var expandedSurface: some View {
        VStack(alignment: .leading, spacing: 10) {
            CommandBarView(viewModel: commandBar)

            Divider().overlay(Color.white.opacity(0.08))

            HStack(alignment: .center, spacing: 12) {
                ClockView(model: clock)
                Spacer(minLength: 8)
                BatteryView(monitor: battery)
                SettingsLink {
                    Image(systemName: "gearshape")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Settings")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .onExitCommand { viewModel.collapse() }
        .onDisappear { commandBar.reset() }
    }

    // MARK: - Shape

    /// Notch silhouette: square top corners (flush with the screen edge), rounded
    /// bottom corners. Expanding only grows downward, so the top stays glued to
    /// the physical notch.
    private var panelShape: some View {
        UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: bottomRadius,
            bottomTrailingRadius: bottomRadius,
            topTrailingRadius: 0,
            style: .continuous
        )
        .fill(.black)
        .overlay(
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: bottomRadius,
                bottomTrailingRadius: bottomRadius,
                topTrailingRadius: 0,
                style: .continuous
            )
            .strokeBorder(.white.opacity(viewModel.isExpanded ? 0.10 : 0.06), lineWidth: 1)
        )
    }

    private var bottomRadius: CGFloat {
        viewModel.isExpanded ? 18 : 10
    }
}

#Preview {
    NotchView(viewModel: NotchViewModel())
        .frame(width: 360, height: 220)
        .background(Color.gray)
}
