import SwiftUI

/// SwiftUI root rendered inside the notch panel.
///
/// Collapsed: blends with the physical notch (minimal, click to open).
/// Expanded: a compact panel with the AI command bar plus a clock/date + battery
/// utility row. Opens on click; closes on Esc or a click outside (handled by the
/// panel). No hover — hover on a screen-saver-level panel is unreliable and was
/// leaving the panel stuck open.
struct NotchView: View {
    @Bindable var viewModel: NotchViewModel
    @State private var commandBar = CommandBarViewModel()
    @State private var battery = BatteryMonitor()
    @State private var clock = ClockModel()

    var body: some View {
        VStack(spacing: 0) {
            collapsedBar
            if viewModel.isExpanded {
                expandedSurface
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(panelShape)
        .animation(.easeOut(duration: 0.22), value: viewModel.isExpanded)
    }

    // MARK: - Collapsed (minimal: hugs the notch, click to open)

    private var collapsedBar: some View {
        Color.clear
            .frame(height: collapsedHeight)
            .contentShape(Rectangle())
            .onTapGesture { viewModel.toggle() }
    }

    private var collapsedHeight: CGFloat {
        viewModel.geometry?.notchHeight ?? NotchGeometry.fallbackHeight
    }

    // MARK: - Expanded (command bar + clock/date + battery)

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
        .onAppear {
            battery.start()
            clock.start()
        }
        .onDisappear {
            battery.stop()
            clock.stop()
            commandBar.reset()
        }
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
            .strokeBorder(.white.opacity(viewModel.isExpanded ? 0.08 : 0), lineWidth: 1)
        )
    }

    private var bottomRadius: CGFloat {
        viewModel.isExpanded ? 18 : 8
    }
}

#Preview {
    NotchView(viewModel: NotchViewModel())
        .frame(width: 360, height: 200)
        .background(Color.gray)
}
