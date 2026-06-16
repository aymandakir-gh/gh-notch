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

    @State private var gearHover = false

    var body: some View {
        Group {
            if viewModel.isExpanded {
                // Grows down out of the notch: scale up from the top edge + fade.
                expanded.transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.97, anchor: .top)),
                    removal: .opacity
                ))
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
        .animation(.easeOut(duration: 0.22), value: viewModel.isExpanded)
    }

    // MARK: - Collapsed: status flanking the physical notch

    private var collapsed: some View {
        HStack(spacing: 0) {
            // Left of the notch: time, hugging the camera. Only the text carries a
            // hit shape — the empty flank stays click-through so menu-bar items
            // beside the notch keep working.
            Text(clock.timeText)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .contentShape(Rectangle())
                .onTapGesture { viewModel.toggle() }
                .padding(.trailing, collapsedGap)
                .frame(width: viewModel.sideWidth, alignment: .trailing)

            // The notch itself — hover (or click) to open.
            Color.clear
                .frame(width: viewModel.collapsedNotchWidth)
                .contentShape(Rectangle())
                .onHover { hovering in if hovering { viewModel.expand() } }
                .onTapGesture { viewModel.toggle() }

            // Right of the notch: battery, hugging the camera.
            collapsedBattery
                .contentShape(Rectangle())
                .onTapGesture { viewModel.toggle() }
                .padding(.leading, collapsedGap)
                .frame(width: viewModel.sideWidth, alignment: .leading)
        }
        .frame(height: viewModel.collapsedNotchHeight)
    }

    /// Gap between the time/battery and the notch edge.
    private let collapsedGap: CGFloat = 10

    private var collapsedBattery: some View {
        HStack(spacing: 5) {
            Image(systemName: collapsedBatterySymbol)
                .font(.system(size: 13))
                .foregroundStyle(collapsedBatteryTint)
                .symbolRenderingMode(.hierarchical)
            Text("\(battery.snapshot.percent)%")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
        }
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
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(gearHover ? Color.primary : Color.secondary)
                        .scaleEffect(gearHover ? 1.1 : 1.0)
                }
                .buttonStyle(.plain)
                .onHover { gearHover = $0 }
                .animation(.easeOut(duration: 0.12), value: gearHover)
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
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: 22,
            bottomTrailingRadius: 22,
            topTrailingRadius: 0,
            style: .continuous
        )
        return shape
            .fill(.black)
            .overlay(shape.strokeBorder(.white.opacity(0.12), lineWidth: 1))
    }
}

#Preview {
    NotchView(viewModel: NotchViewModel())
        .frame(width: 480, height: 220)
        .background(Color.gray)
}
