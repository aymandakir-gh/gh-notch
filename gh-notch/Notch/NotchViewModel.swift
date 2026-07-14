import AppKit
import Observation

/// Observable state for the notch panel, driven by `NotchStateMachine`.
///
/// All UI inputs and feature posts funnel through `handle(_:)`; this class owns
/// the auto-dismiss clock the (pure) machine schedules, the sampled geometry,
/// and the pin set. The panel window reads `layout` for its one pre-sized
/// envelope; the SwiftUI layer reads `state` + `islandSize(for:)` and animates
/// between island sizes — the window itself never resizes on state changes.
@MainActor
@Observable
final class NotchViewModel {

    /// Current presentation state. Mutate only via `handle(_:)`.
    private(set) var state: NotchState = .collapsed

    /// The latest geometry sampled from the panel's screen. `nil` before the
    /// first sample (e.g. headless boot); the panel skips positioning until set.
    private(set) var geometry: NotchGeometry?

    /// Frame of the screen hosting this panel (AppKit coordinates).
    private(set) var screenFrame: CGRect = .zero

    /// User override for notch width (Settings → General; slice E adds the UI).
    var notchWidthOverride: CGFloat?

    /// Features that must keep the expanded panel open register a reason here
    /// via `setPin`. Pinned suppresses hoverExit/clickAway collapse.
    private(set) var pinReasons: Set<PinReason> = []

    /// Measured height of the expanded content (the view reports it; drives the
    /// expanded island height and the panel's interactive-rect hit testing).
    /// Starts at a sane default so the first expansion isn't a zero-height flash.
    var expandedContentHeight: CGFloat = 360

    /// Fired after `state` actually changes (the panel manages its click-away
    /// monitor here).
    @ObservationIgnored var onStateChange: ((NotchState) -> Void)?

    /// Fired after geometry/screen updates (the panel re-applies its envelope).
    @ObservationIgnored var onGeometryChange: (() -> Void)?

    @ObservationIgnored private var dismissTask: Task<Void, Never>?
    @ObservationIgnored private let durations: TransientDurations

    init(durations: TransientDurations = .standard) {
        self.durations = durations
    }

    // MARK: - Derived

    var isExpanded: Bool { state == .expanded }
    var pinned: Bool { !pinReasons.isEmpty }

    var layout: NotchLayout? {
        geometry.map { NotchLayout(geometry: $0, screenFrame: screenFrame) }
    }

    /// Notch width (user override, else sampled).
    var collapsedNotchWidth: CGFloat {
        layout?.notchWidth(override: notchWidthOverride) ?? NotchGeometry.fallbackWidth
    }

    /// Notch / menu-bar height.
    var collapsedNotchHeight: CGFloat {
        geometry?.notchHeight ?? NotchGeometry.fallbackHeight
    }

    /// Width of each interactive status flank beside the notch when collapsed.
    var sideWidth: CGFloat {
        (layout?.metrics ?? .standard).sideWidth
    }

    /// Island size for a state, using the measured expanded content height.
    func islandSize(for state: NotchState) -> CGSize {
        guard let layout else {
            return CGSize(width: NotchGeometry.fallbackWidth, height: NotchGeometry.fallbackHeight)
        }
        return layout.islandSize(
            for: state,
            override: notchWidthOverride,
            contentHeight: expandedContentHeight
        )
    }

    // MARK: - Inputs

    /// Feed one event through the state machine, applying its transition and
    /// managing the auto-dismiss timer it schedules (or cancels).
    func handle(_ event: NotchEvent) {
        let transition = NotchStateMachine.transition(
            from: state, on: event, pinned: pinned, durations: durations
        )
        let changed = transition.next != state
        if changed { state = transition.next }

        switch transition.next {
        case .peek, .hud, .activity:
            if let after = transition.autoDismissAfter, let kind = transientKind(of: transition.next) {
                scheduleAutoDismiss(kind: kind, after: after)
            }
        case .collapsed, .expanded:
            cancelAutoDismiss()
        }

        // A stale `timeout` the state machine ignores can orphan the dismiss clock:
        // the completing task nils `dismissTask` before calling `handle`, and an
        // ignored post leaves `autoDismissAfter` nil so nothing reschedules.
        if case .timeout(let firedKind) = event,
           let currentKind = transientKind(of: state),
           firedKind != currentKind,
           !hasPendingAutoDismiss {
            scheduleAutoDismiss(kind: currentKind, after: duration(for: currentKind))
        }

        if changed { onStateChange?(state) }
    }

    func update(geometry: NotchGeometry, screenFrame: CGRect) {
        self.geometry = geometry
        self.screenFrame = screenFrame
        onGeometryChange?()
    }

    func setPin(_ reason: PinReason, _ active: Bool) {
        if active {
            pinReasons.insert(reason)
        } else {
            pinReasons.remove(reason)
        }
    }

    // MARK: - Hit testing

    /// Regions of the panel (in its bottom-left-origin view coordinates) that
    /// should receive mouse events for the CURRENT state. Everything else in the
    /// pre-sized envelope must fall through to windows below — the envelope
    /// spans well past the visible island (docs/PARITY-ROADMAP.md §2.7 risk).
    func interactiveRects() -> [CGRect] {
        guard let layout else { return [] }
        let panel = layout.panelFrame(override: notchWidthOverride)

        func topCentered(_ size: CGSize) -> CGRect {
            CGRect(
                x: ((panel.width - size.width) / 2).rounded(),
                y: panel.height - size.height,
                width: size.width,
                height: size.height
            )
        }

        switch state {
        case .collapsed:
            // The whole strip (flank + notch + flank); SwiftUI contentShape
            // narrows hits to the actual controls so empty flank areas stay
            // click-through within it.
            let strip = CGSize(
                width: layout.collapsedStripWidth(override: notchWidthOverride),
                height: layout.geometry.notchHeight
            )
            return [topCentered(strip)]
        case .peek, .hud, .activity, .expanded:
            return [topCentered(islandSize(for: state))]
        }
    }

    // MARK: - Auto-dismiss clock

    /// Whether a transient auto-dismiss is currently scheduled (test hook).
    var hasPendingAutoDismiss: Bool {
        guard let dismissTask else { return false }
        return !dismissTask.isCancelled
    }

    private func transientKind(of state: NotchState) -> TransientKind? {
        switch state {
        case .peek: return .peek
        case .hud: return .hud
        case .activity: return .activity
        case .collapsed, .expanded: return nil
        }
    }

    private func duration(for kind: TransientKind) -> TimeInterval {
        switch kind {
        case .peek: return durations.peek
        case .hud: return durations.hud
        case .activity: return durations.activity
        }
    }

    private func scheduleAutoDismiss(kind: TransientKind, after seconds: TimeInterval) {
        dismissTask?.cancel()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            guard let self else { return }
            self.dismissTask = nil
            self.handle(.timeout(kind))
        }
    }

    private func cancelAutoDismiss() {
        dismissTask?.cancel()
        dismissTask = nil
    }
}
