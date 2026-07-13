import AppKit
import Observation
import SwiftUI

/// Owns one notch panel (+ view model + gesture monitor) per selected screen,
/// tearing everything down and rebuilding on display changes — the
/// ghost-window-proof approach (docs/PARITY-ROADMAP.md §2.5).
///
/// System-wide feature models (battery, clock, calendar, shelf) live HERE, not
/// per panel: the shelf's disk index must have a single writer, and duplicated
/// monitors would mean duplicated timers per display.
@MainActor
final class PanelManager {

    let battery = BatteryMonitor()
    let clock = ClockModel()
    let calendar = CalendarModel()
    let shelf = ShelfStore()

    private let settings: AppSettingsStore
    private var panels: [NotchPanel] = []
    private var viewModels: [NotchViewModel] = []
    private var monitors: [GestureMonitor] = []
    private var rebuildTask: Task<Void, Never>?

    init(settings: AppSettingsStore = .shared) {
        self.settings = settings
    }

    func start() {
        battery.start()
        clock.start()
        calendar.start()
        rebuild()
        observeSettings()
    }

    /// Debounced rebuild — `didChangeScreenParametersNotification` fires in
    /// bursts during display reconfiguration.
    func scheduleRebuild() {
        rebuildTask?.cancel()
        rebuildTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            self?.rebuild()
        }
    }

    func rebuild() {
        teardownPanels()

        let screens = NSScreen.screens
        guard !screens.isEmpty else { return }
        let descriptors = screens.map(ScreenDescriptor.init(screen:))

        for index in DisplaySelection.targetIndices(of: descriptors, mode: settings.showOnDisplays) {
            let screen = screens[index]
            let viewModel = NotchViewModel()
            viewModel.notchWidthOverride = settings.notchWidthOverride.map { CGFloat($0) }

            let panel = NotchPanel(viewModel: viewModel)
            panel.attachContent(NotchView(
                viewModel: viewModel,
                battery: battery,
                clock: clock,
                calendar: calendar,
                shelf: shelf
            ))
            viewModel.update(geometry: .sample(screen), screenFrame: screen.frame)
            panel.orderFrontRegardless()

            let monitor = GestureMonitor(viewModel: viewModel, panel: panel)
            monitor.start()

            panels.append(panel)
            viewModels.append(viewModel)
            monitors.append(monitor)
        }
    }

    func stop() {
        rebuildTask?.cancel()
        teardownPanels()
        battery.stop()
        clock.stop()
        calendar.stop()
    }

    private func teardownPanels() {
        monitors.forEach { $0.stop() }
        panels.forEach { $0.close() } // isReleasedWhenClosed=false: ARC owns them
        monitors.removeAll()
        panels.removeAll()
        viewModels.removeAll()
    }

    /// Re-arm-on-fire observation of the display-affecting settings, so the
    /// Settings window needs no direct handle on the manager.
    private func observeSettings() {
        withObservationTracking {
            _ = settings.showOnDisplays
            _ = settings.notchWidthOverride
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let override = self.settings.notchWidthOverride.map { CGFloat($0) }
                for viewModel in self.viewModels {
                    viewModel.notchWidthOverride = override
                }
                self.scheduleRebuild()
                self.observeSettings()
            }
        }
    }
}

extension ScreenDescriptor {
    @MainActor
    init(screen: NSScreen) {
        let screenNumberKey = NSDeviceDescriptionKey("NSScreenNumber")
        let displayID = (screen.deviceDescription[screenNumberKey] as? NSNumber)
            .map { CGDirectDisplayID($0.uint32Value) }
        self.init(
            isBuiltIn: displayID.map { CGDisplayIsBuiltin($0) != 0 } ?? false,
            hasNotch: screen.safeAreaInsets.top > 0,
            isMenuBarPrimary: screen.frame.origin == .zero
        )
    }
}
