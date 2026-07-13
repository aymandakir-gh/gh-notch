import AppKit
import SwiftUI

/// `NSHostingView` that constrains mouse events to the view model's interactive
/// regions. The panel window is pre-sized to its maximum (expanded) envelope and
/// never resizes, so most of it is empty air — `hitTest` must return nil there
/// or an invisible rectangle would swallow clicks meant for windows below.
/// Inside the interactive rects, SwiftUI's own hit testing (contentShape) takes
/// over, preserving the fine-grained click-through of the collapsed flanks.
final class NotchHostingView<Content: View>: NSHostingView<Content> {
    var interactiveRects: (() -> [CGRect])?

    override func hitTest(_ point: NSPoint) -> NSView? {
        if let rects = interactiveRects?() {
            let local = convert(point, from: superview)
            guard rects.contains(where: { $0.contains(local) }) else { return nil }
        }
        return super.hitTest(point)
    }
}

/// Borderless `NSPanel` that hosts the SwiftUI notch UI.
///
/// Renders above the menu bar (`.screenSaver` level), joins every Space, is
/// non-activating (clicking it never steals key focus from the user's app), and
/// is transparent so SwiftUI controls the visible shape. Pre-sized to the
/// maximum envelope (`NotchLayout.panelFrame`) — expand/collapse is a SwiftUI
/// morph inside the fixed window, never a window resize.
final class NotchPanel: NSPanel {

    private let viewModel: NotchViewModel
    private var clickAwayMonitor: Any?

    init(viewModel: NotchViewModel) {
        self.viewModel = viewModel

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: NotchGeometry.fallbackWidth, height: NotchGeometry.fallbackHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        isReleasedWhenClosed = false             // ARC owns panels; PanelManager closes them
        level = .screenSaver                     // above the menu bar
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true

        // Visible on every Space, and over full-screen apps' menu bar region.
        collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .fullScreenAuxiliary,
            .ignoresCycle
        ]

        // The window envelope changes only when screen geometry does; state
        // changes just toggle the click-away monitor.
        viewModel.onGeometryChange = { [weak self] in
            self?.applyPanelEnvelope()
        }
        viewModel.onStateChange = { [weak self] state in
            self?.updateClickAwayMonitor(isExpanded: state == .expanded)
        }
    }

    deinit {
        if let clickAwayMonitor {
            NSEvent.removeMonitor(clickAwayMonitor)
        }
    }

    /// Borderless panels return `false` by default; allow key so SwiftUI focus
    /// (the command bar text field) works when expanded.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// Install the SwiftUI root as the panel's content, wiring the interactive
    /// hit-test regions to the view model.
    func attachContent<Content: View>(_ content: Content) {
        let hosting = NotchHostingView(rootView: content)
        hosting.interactiveRects = { [weak viewModel] in
            viewModel?.interactiveRects() ?? []
        }
        hosting.translatesAutoresizingMaskIntoConstraints = true
        hosting.autoresizingMask = [.width, .height]
        contentView = hosting
    }

    /// Sample the active screen and apply the (state-independent) envelope.
    /// Safe to call repeatedly (screen parameter changes).
    func repositionToActiveScreen() {
        guard let screen = NotchGeometry.activeScreen() else { return }
        viewModel.update(geometry: .sample(screen), screenFrame: screen.frame)
    }

    private func applyPanelEnvelope() {
        guard let layout = viewModel.layout else { return }
        setFrame(layout.panelFrame(override: viewModel.notchWidthOverride), display: true)
    }

    /// While expanded, watch for clicks outside the panel (i.e. in another app or
    /// on the desktop) and feed a clickAway event (the machine respects pins).
    /// Global monitors only fire for events the app does not receive itself, so
    /// clicks inside the panel are unaffected.
    private func updateClickAwayMonitor(isExpanded: Bool) {
        if isExpanded {
            guard clickAwayMonitor == nil else { return }
            clickAwayMonitor = NSEvent.addGlobalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown]
            ) { [weak self] _ in
                self?.viewModel.handle(.clickAway)
            }
        } else if let monitor = clickAwayMonitor {
            NSEvent.removeMonitor(monitor)
            clickAwayMonitor = nil
        }
    }
}
