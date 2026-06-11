import AppKit
import SwiftUI

/// `NSHostingView` that reports when the pointer leaves its bounds, so the panel
/// can auto-collapse on mouse-out (hover-to-peek behaviour). Tracking areas are
/// permission-free, unlike global event monitors.
final class MouseAwareHostingView<Content: View>: NSHostingView<Content> {
    var onMouseExited: (() -> Void)?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas {
            removeTrackingArea(area)
        }
        addTrackingArea(NSTrackingArea(
            rect: .zero,
            options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }

    override func mouseExited(with event: NSEvent) {
        onMouseExited?()
    }
}

/// Borderless `NSPanel` that hosts the SwiftUI notch UI.
///
/// Renders above the menu bar (`.screenSaver` level), joins every Space, is
/// non-activating (clicking it never steals key focus from the user's app), and
/// is transparent so SwiftUI controls the visible shape.
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
        level = .screenSaver                     // above the menu bar
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true           // needed for mouse-exit tracking

        // Visible on every Space, and over full-screen apps' menu bar region.
        collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .fullScreenAuxiliary,
            .ignoresCycle
        ]

        // Re-frame the window and manage the click-away monitor on expand/collapse.
        viewModel.onLayoutChange = { [weak self] in
            self?.applyCurrentFrame()
            self?.updateClickAwayMonitor()
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

    /// Install the SwiftUI root as the panel's content, wiring mouse-exit to
    /// auto-collapse.
    func attachContent<Content: View>(_ content: Content) {
        let hosting = MouseAwareHostingView(rootView: content)
        hosting.onMouseExited = { [weak self] in
            self?.viewModel.collapseOnMouseExit()
        }
        hosting.translatesAutoresizingMaskIntoConstraints = true
        hosting.autoresizingMask = [.width, .height]
        contentView = hosting
    }

    /// Sample the active screen and move/size the panel to match the view model's
    /// current frame. Safe to call repeatedly (screen changes, expand/collapse).
    func repositionToActiveScreen() {
        guard let geometry = NotchGeometry.forActiveScreen() else { return }
        viewModel.update(geometry: geometry)
        applyCurrentFrame()
    }

    /// Resize/reposition to whatever the view model currently reports, animating
    /// the expand/collapse transition.
    func applyCurrentFrame(animated: Bool = true) {
        guard let frame = viewModel.currentFrame else { return }
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.20
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                animator().setFrame(frame, display: true)
            }
        } else {
            setFrame(frame, display: true)
        }
    }

    /// While expanded, watch for clicks outside the panel (i.e. in another app or
    /// on the desktop) and collapse. Global monitors only fire for events the app
    /// does not receive itself, so clicks inside the panel are unaffected.
    private func updateClickAwayMonitor() {
        if viewModel.isExpanded {
            guard clickAwayMonitor == nil else { return }
            clickAwayMonitor = NSEvent.addGlobalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown]
            ) { [weak self] _ in
                self?.viewModel.collapse()
            }
        } else if let monitor = clickAwayMonitor {
            NSEvent.removeMonitor(monitor)
            clickAwayMonitor = nil
        }
    }
}
