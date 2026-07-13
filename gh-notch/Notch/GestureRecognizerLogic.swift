import CoreGraphics
import Foundation

/// One scroll event, abstracted away from AppKit so the recognizer is pure and
/// CI-testable with synthetic streams (`GestureMonitor` maps `NSEvent`s in).
struct ScrollSample: Equatable {
    var deltaX: CGFloat
    var deltaY: CGFloat
    var phase: ScrollPhase
    var momentumPhase: ScrollPhase
    var hasPreciseDeltas: Bool
    var timestamp: TimeInterval
}

/// Subset of `NSEvent.Phase` the recognizer cares about. Mouse-wheel events
/// carry no phases at all (`none` throughout) — the recognizer handles that
/// via accumulation + silence reset.
enum ScrollPhase: Equatable {
    case none
    case began
    case changed
    case ended
    case cancelled
}

/// Pure two-finger-swipe recognizer (docs/PARITY-ROADMAP.md §2.4). Cleanroom:
/// written from published behavioral facts only — GPL gesture sources stay
/// closed while this file is edited.
///
/// Lifecycle: idle → tracking (accumulate deltas) → commit (emit ONE direction)
/// → draining (swallow the finger tail and ALL momentum — the classic
/// momentum re-trigger bug) → idle on momentum end or silence.
///
/// Direction convention: positive `deltaY` → `.down`, positive `deltaX` →
/// `.right` (finger direction under natural scrolling). `GestureMonitor` owns
/// any semantic inversion; flagged for real-device verification in STATUS.md.
struct GestureRecognizerLogic {

    struct Config: Equatable {
        /// Accumulated points on the dominant axis before a swipe commits.
        var activationThreshold: CGFloat = 4
        /// Per-event deltas below this are treated as zero (sensor noise).
        var noiseFloor: CGFloat = 0.2
        /// Dominant axis must beat the other by this ratio to commit.
        var axisDominanceRatio: CGFloat = 1.5
        /// Multiplier for non-precise (mouse wheel / Magic Mouse) deltas.
        var mouseAmplification: CGFloat = 8
        /// A gap this long between events resets whatever was in flight.
        var silenceReset: TimeInterval = 0.3
    }

    enum Phase: Equatable {
        case idle
        case tracking
        case draining
    }

    private(set) var phase: Phase = .idle
    private var accumulatedX: CGFloat = 0
    private var accumulatedY: CGFloat = 0
    private var lastTimestamp: TimeInterval?
    let config: Config

    init(config: Config = Config()) {
        self.config = config
    }

    /// Feed one sample; returns a direction exactly once per committed swipe.
    mutating func consume(_ sample: ScrollSample) -> SwipeDirection? {
        if let last = lastTimestamp, sample.timestamp - last > config.silenceReset {
            reset() // long gap: whatever was in flight is over
        }
        lastTimestamp = sample.timestamp

        if sample.momentumPhase != .none {
            consumeMomentum(sample.momentumPhase)
            return nil
        }

        switch sample.phase {
        case .began:
            // Fresh fingers always start a new gesture — even mid-drain.
            phase = .tracking
            accumulatedX = 0
            accumulatedY = 0
            return nil
        case .cancelled:
            if phase == .tracking { reset() }
            return nil
        case .ended:
            // Tracking that never committed just ends; a committed gesture
            // stays draining until its momentum finishes or silence.
            if phase == .tracking { reset() }
            return nil
        case .changed, .none:
            return accumulate(sample)
        }
    }

    private mutating func consumeMomentum(_ momentum: ScrollPhase) {
        switch phase {
        case .draining:
            if momentum == .ended || momentum == .cancelled { reset() }
        case .tracking:
            // Momentum implies the fingers already lifted without a commit.
            reset()
        case .idle:
            break // stray momentum tail — ignore
        }
    }

    private mutating func accumulate(_ sample: ScrollSample) -> SwipeDirection? {
        if phase == .draining { return nil }
        if phase == .idle {
            // Wheel/mouse events carry no began phase; a fresh burst tracks.
            phase = .tracking
            accumulatedX = 0
            accumulatedY = 0
        }

        var deltaX = sample.deltaX
        var deltaY = sample.deltaY
        if !sample.hasPreciseDeltas {
            deltaX *= config.mouseAmplification
            deltaY *= config.mouseAmplification
        }
        if abs(deltaX) < config.noiseFloor { deltaX = 0 }
        if abs(deltaY) < config.noiseFloor { deltaY = 0 }
        accumulatedX += deltaX
        accumulatedY += deltaY

        guard let direction = committedDirection() else { return nil }
        phase = .draining // one emission per gesture; swallow the tail
        accumulatedX = 0
        accumulatedY = 0
        return direction
    }

    private func committedDirection() -> SwipeDirection? {
        let absX = abs(accumulatedX)
        let absY = abs(accumulatedY)
        if absY >= config.activationThreshold, absY >= absX * config.axisDominanceRatio {
            return accumulatedY > 0 ? .down : .up
        }
        if absX >= config.activationThreshold, absX >= absY * config.axisDominanceRatio {
            return accumulatedX > 0 ? .right : .left
        }
        return nil
    }

    private mutating func reset() {
        phase = .idle
        accumulatedX = 0
        accumulatedY = 0
    }
}
