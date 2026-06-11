import AppKit
import SwiftUI

/// Borderless `NSPanel` that hosts the SwiftUI notch UI.
///
/// Renders above the menu bar (`.screenSaver` level), joins every Space, is
/// non-activating (clicking it never steals key focus from the user's app), and
/// is transparent so SwiftUI controls the visible shape.
final class NotchPanel: NSPanel {

    private let viewModel: NotchViewModel

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

        // Visible on every Space, and over full-screen apps' menu bar region.
        collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .fullScreenAuxiliary,
            .ignoresCycle
        ]

        // Re-frame the window whenever the view model expands/collapses.
        viewModel.onLayoutChange = { [weak self] in
            self?.applyCurrentFrame()
        }
    }

    /// Borderless panels return `false` by default; allow key so SwiftUI focus
    /// (e.g. the future AI command bar text field) can work when expanded.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// Install the SwiftUI root as the panel's content.
    func attachContent<Content: View>(_ content: Content) {
        let hosting = NSHostingView(rootView: content)
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
                context.duration = 0.22
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                animator().setFrame(frame, display: true)
            }
        } else {
            setFrame(frame, display: true)
        }
    }
}
