import SwiftUI

/// SwiftUI root rendered inside the (pre-sized, never-resizing) notch panel.
///
/// Collapsed: the v0.3 look — a thin transparent status strip at menu-bar level,
/// time to the left of the camera, battery to the right. Hover the notch (or
/// click) to open. Transients (peek/hud/activity) draw a small black island
/// dipping below the notch. Expanded: the black dropdown, height driven by its
/// measured content (capped), springing between states per `NotchMotion`.
/// Closes on Esc, click-away, swipe up, or pointer-exit (unless pinned).
struct NotchView: View {
    @Bindable var viewModel: NotchViewModel
    // System-wide models are shared across panels (PanelManager owns them);
    // the command bar's text state stays per-panel.
    let battery: BatteryMonitor
    let clock: ClockModel
    let calendar: CalendarModel
    let shelf: ShelfStore
    @State private var commandBar = CommandBarViewModel()

    @State private var gearHover = false
    @State private var hoverTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let settings = AppSettingsStore.shared

    var body: some View {
        Group {
            switch viewModel.state {
            case .collapsed:
                collapsed.transition(.opacity)
            case .peek, .hud, .activity:
                transientIsland.transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.9, anchor: .top)),
                    removal: .opacity
                ))
            case .expanded:
                // Grows down out of the notch: scale up from the top edge + fade.
                expanded.transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.97, anchor: .top)),
                    removal: .opacity
                ))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onChange(of: commandBar.shouldStayOpen) { _, active in
            viewModel.setPin(.commandBar, active)
        }
        .onChange(of: calendar.isRequestingAccess) { _, active in
            viewModel.setPin(.permissionDialog, active)
        }
        .onChange(of: shelf.isDraggingOut) { _, active in
            viewModel.setPin(.shelfDrag, active)
        }
        .animation(NotchMotion.stateChange(reduceMotion: reduceMotion), value: viewModel.state)
        .animation(NotchMotion.stateChange(reduceMotion: reduceMotion), value: viewModel.expandedContentHeight)
    }

    // MARK: - Collapsed: status flanking the physical notch (v0.3 look preserved)

    private var collapsed: some View {
        HStack(spacing: 0) {
            // Left of the notch: the next event (when granted) + time, hugging the
            // camera. Only this group carries a hit shape — the empty flank stays
            // click-through so menu-bar items beside the notch keep working.
            HStack(spacing: 8) {
                if calendar.permission == .granted, let next = calendar.nextEvent {
                    CalendarChip(event: next, now: clock.now)
                }
                Text(clock.timeText)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
            }
            .contentShape(Rectangle())
            .onTapGesture { viewModel.handle(.tap) }
            .padding(.trailing, collapsedGap)
            .frame(width: viewModel.sideWidth, alignment: .trailing)

            // The notch itself — dwell-hover (or click) to open. blendCollapsed
            // off draws the island extension even while collapsed.
            Group {
                if settings.blendCollapsed {
                    Color.clear
                } else {
                    NotchIslandBackground(state: .collapsed)
                }
            }
            .frame(width: viewModel.collapsedNotchWidth)
            .contentShape(Rectangle())
            .onHover { hovering in
                hoverTask?.cancel()
                hoverTask = nil
                guard hovering else { return }
                let dwell = settings.hoverDwell
                hoverTask = Task {
                    try? await Task.sleep(nanoseconds: UInt64(dwell * 1_000_000_000))
                    guard !Task.isCancelled else { return }
                    viewModel.handle(.hoverEnter)
                }
            }
            .onTapGesture { viewModel.handle(.tap) }

            // Right of the notch: battery, hugging the camera.
            collapsedBattery
                .contentShape(Rectangle())
                .onTapGesture { viewModel.handle(.tap) }
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

    // MARK: - Transients: a small island dipping below the notch
    // Placeholder content until v0.5 (peeks), v0.6 (huds), v0.7 (activities)
    // give these real payloads — the states are unreachable until then, but the
    // island morph and layout are final now.

    private var transientIsland: some View {
        let size = viewModel.islandSize(for: viewModel.state)
        return HStack(spacing: 6) {
            Image(systemName: transientSymbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
        }
        .frame(width: size.width, height: size.height, alignment: .bottom)
        .padding(.bottom, 0)
        .background(NotchIslandBackground(state: viewModel.state))
        .onTapGesture { viewModel.handle(.tap) }
    }

    private var transientSymbol: String {
        switch viewModel.state {
        case .hud(.volume): return "speaker.wave.2.fill"
        case .hud(.brightness): return "sun.max.fill"
        case .hud(.keyboardBacklight): return "keyboard"
        case .hud(.capsLock): return "capslock.fill"
        case .hud(.charging): return "bolt.fill"
        case .activity: return "circle.hexagongrid.fill"
        case .peek: return "music.note"
        case .collapsed, .expanded: return "circle"
        }
    }

    // MARK: - Expanded: dropdown below the notch, content-driven height

    private var expanded: some View {
        let size = viewModel.islandSize(for: .expanded)
        return VStack(spacing: 0) {
            Color.clear.frame(height: viewModel.collapsedNotchHeight) // blends with the notch
            expandedScroll
        }
        .frame(width: size.width, height: size.height)
        .background(NotchIslandBackground(state: .expanded))
        .onHover { hovering in
            if !hovering { viewModel.handle(.hoverExit) }
        }
    }

    /// The content column, measured so the island hugs it (capped by
    /// `NotchLayout.maxExpandedContentHeight`); scrolls only when capped.
    private var expandedScroll: some View {
        ScrollView(.vertical) {
            expandedSurface
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height
                } action: { height in
                    viewModel.expandedContentHeight = height
                }
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollIndicators(.never)
    }

    private var expandedSurface: some View {
        let sections = settings.visibleSections
        return VStack(alignment: .leading, spacing: 12) {
            ForEach(sections) { section in
                sectionBody(section)
                if section != sections.last {
                    Divider().overlay(Color.white.opacity(0.08))
                }
            }
        }
        .padding(16)
        .onExitCommand { viewModel.handle(.escape) }
        .task {
            // Expanding the panel is the user activating the feature — only now do
            // we (lazily) request calendar access, never at launch.
            await calendar.requestAccess()
        }
        .onDisappear {
            commandBar.reset()
            gearHover = false // avoid the gear re-appearing pre-hovered if collapsed via Esc
        }
    }

    @ViewBuilder
    private func sectionBody(_ section: ExpandedSection) -> some View {
        switch section {
        case .commandBar:
            CommandBarView(viewModel: commandBar)
        case .calendar:
            CalendarAgendaView(model: calendar, now: clock.now)
        case .shelf:
            ShelfView(store: shelf)
        case .statusRow:
            statusRow
        }
    }

    private var statusRow: some View {
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
            .animation(NotchMotion.micro, value: gearHover)
            .help("Settings")
        }
    }
}

#Preview {
    NotchView(
        viewModel: NotchViewModel(),
        battery: BatteryMonitor(),
        clock: ClockModel(),
        calendar: CalendarModel(),
        shelf: ShelfStore()
    )
    .frame(width: 480, height: 220)
    .background(Color.gray)
}
