import SwiftUI

/// SwiftUI root rendered inside the notch panel.
///
/// Collapsed: a black pill that hugs the notch. Expanded (on hover/click): the
/// AI command bar and the battery HUD.
struct NotchView: View {
    @Bindable var viewModel: NotchViewModel
    @State private var isHovering = false
    @State private var commandBar = CommandBarViewModel()
    @State private var battery = BatteryMonitor()

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
        .onHover { hovering in
            isHovering = hovering
            // Hover-to-peek: expand on enter. On leave, only collapse if the
            // command bar isn't mid-interaction (typing, a result on screen, or a
            // request in flight) — otherwise the panel would vanish under the user.
            if hovering {
                viewModel.expand()
            } else if !commandBar.shouldStayOpen {
                viewModel.collapse()
            }
        }
        .animation(.easeOut(duration: 0.22), value: viewModel.isExpanded)
    }

    // MARK: - Collapsed

    private var collapsedBar: some View {
        HStack {
            Spacer(minLength: 0)
        }
        .frame(height: collapsedHeight)
        .contentShape(Rectangle())
        .onTapGesture { viewModel.toggle() }
    }

    private var collapsedHeight: CGFloat {
        viewModel.geometry?.notchHeight ?? NotchGeometry.fallbackHeight
    }

    // MARK: - Expanded

    private var expandedSurface: some View {
        VStack(alignment: .leading, spacing: 12) {
            CommandBarView(viewModel: commandBar)
            Divider()
                .overlay(Color.white.opacity(0.1))
            BatteryView(monitor: battery)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .onAppear { battery.start() }
        .onDisappear {
            battery.stop()
            commandBar.reset()
        }
    }

    // MARK: - Shape

    /// The notch silhouette: square top corners (flush with the screen edge),
    /// rounded bottom corners. Expanding only grows downward, so the top stays
    /// glued to the physical notch.
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
        viewModel.isExpanded ? 16 : 10
    }
}

#Preview {
    NotchView(viewModel: NotchViewModel())
        .frame(width: 380, height: 200)
        .background(Color.gray)
}
