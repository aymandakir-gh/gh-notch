import SwiftUI

/// SwiftUI root rendered inside the notch panel.
///
/// Collapsed: a thin status bar at menu-bar level — time to the left of the
/// camera, battery to the right (transparent, so it reads as part of the menu
/// bar). Hover the notch (or click anywhere) to open.
/// Expanded: a centered dropdown below the notch — AI command bar + clock/date +
/// battery + Settings. Closes on Esc, a click outside, or when the pointer leaves
/// (unless the command bar is in use).
struct NotchView: View {
    @Bindable var viewModel: NotchViewModel
    @State private var commandBar = CommandBarViewModel()
    @State private var battery = BatteryMonitor()
    @State private var clock = ClockModel()

    var body: some View {
        Group {
            if viewModel.isExpanded {
                expanded.transition(.opacity)
            } else {
                collapsed.transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            battery.start()
            clock.start()
        }
        .onChange(of: commandBar.shouldStayOpen) { _, stay in
            viewModel.pinnedOpen = stay
        }
        .animation(.easeOut(duration: 0.2), value: viewModel.isExpanded)
    }

    // MARK: - Collapsed: status flanking the physical notch

    private var collapsed: some View {
        HStack(spacing: 0) {
            // Left of the notch: time
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                Text(clock.timeText)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
            }
            .frame(width: viewModel.sideWidth)
            .padding(.trailing, 12)
            .contentShape(Rectangle())
            .onTapGesture { viewModel.toggle() }

            // The notch itself — hover (or click) to open
            Color.clear
                .frame(width: viewModel.collapsedNotchWidth)
                .contentShape(Rectangle())
                .onHover { hovering in if hovering { viewModel.expand() } }
                .onTapGesture { viewModel.toggle() }

            // Right of the notch: battery
            HStack(spacing: 5) {
                Image(systemName: collapsedBatterySymbol)
                    .font(.system(size: 12))
                    .foregroundStyle(collapsedBatteryTint)
                    .symbolRenderingMode(.hierarchical)
                Text("\(battery.snapshot.percent)%")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                Spacer(minLength: 0)
            }
            .frame(width: viewModel.sideWidth)
            .padding(.leading, 12)
            .contentShape(Rectangle())
            .onTapGesture { viewModel.toggle() }
        }
        .frame(height: viewModel.collapsedNotchHeight)
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
        return .white
    }

    // MARK: - Expanded: dropdown below the notch

    private var expanded: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: viewModel.collapsedNotchHeight) // blends with the notch
            expandedSurface
                .frame(height: viewModel.expandedSize.height)
        }
        .background(panelShape)
    }

    private var expandedSurface: some View {
        VStack(alignment: .leading, spacing: 12) {
            CommandBarView(viewModel: commandBar)

            Divider().overlay(Color.white.opacity(0.08))

            HStack(alignment: .center, spacing: 12) {
                ClockView(model: clock)
                Spacer(minLength: 8)
                BatteryView(monitor: battery)
                SettingsLink {
                    Image(systemName: "gearshape")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Settings")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(16)
        .onExitCommand { viewModel.collapse() }
        .onDisappear { commandBar.reset() }
    }

    // MARK: - Shape (rounded dropdown, square top so it hugs the notch)

    private var panelShape: some View {
        UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: 20,
            bottomTrailingRadius: 20,
            topTrailingRadius: 0,
            style: .continuous
        )
        .fill(.black)
        .overlay(
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 20,
                bottomTrailingRadius: 20,
                topTrailingRadius: 0,
                style: .continuous
            )
            .strokeBorder(.white.opacity(0.10), lineWidth: 1)
        )
    }
}

#Preview {
    NotchView(viewModel: NotchViewModel())
        .frame(width: 480, height: 220)
        .background(Color.gray)
}
