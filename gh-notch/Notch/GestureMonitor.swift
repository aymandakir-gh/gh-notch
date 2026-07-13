import AppKit

/// Feeds panel-bound scroll events through `GestureRecognizerLogic` and turns
/// commits into `NotchEvent.swipe` + a haptic tick.
///
/// Local monitor only (events already destined for our windows) — no
/// permissions. Gestures are recognized in collapsed/transient states; while
/// expanded, scroll events pass through untouched so the content ScrollView
/// keeps working (swipe-up-to-close while expanded is machine-supported but
/// deliberately not wired until a non-scrolling chrome region exists).
@MainActor
final class GestureMonitor {

    private let viewModel: NotchViewModel
    private weak var panel: NSPanel?
    private var monitor: Any?
    private var recognizer: GestureRecognizerLogic

    init(
        viewModel: NotchViewModel,
        panel: NSPanel,
        config: GestureRecognizerLogic.Config = .init()
    ) {
        self.viewModel = viewModel
        self.panel = panel
        self.recognizer = GestureRecognizerLogic(config: config)
    }

    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self else { return event }
            return self.process(event)
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }

    private func process(_ event: NSEvent) -> NSEvent? {
        guard event.window === panel else { return event }

        switch viewModel.state {
        case .expanded:
            return event // never eat content scrolling
        case .collapsed, .peek, .hud, .activity:
            break
        }

        if let direction = recognizer.consume(ScrollSample(event: event)) {
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
            viewModel.handle(.swipe(direction))
        }
        // Over the strip/island a scroll has no other meaning — consume it.
        return nil
    }
}

extension ScrollSample {
    @MainActor
    init(event: NSEvent) {
        self.init(
            deltaX: event.scrollingDeltaX,
            deltaY: event.scrollingDeltaY,
            phase: ScrollPhase(event.phase),
            momentumPhase: ScrollPhase(event.momentumPhase),
            hasPreciseDeltas: event.hasPreciseScrollingDeltas,
            timestamp: event.timestamp
        )
    }
}

extension ScrollPhase {
    init(_ phase: NSEvent.Phase) {
        if phase.contains(.began) {
            self = .began
        } else if phase.contains(.changed) {
            self = .changed
        } else if phase.contains(.ended) {
            self = .ended
        } else if phase.contains(.cancelled) {
            self = .cancelled
        } else {
            self = .none
        }
    }
}
