import Foundation

/// Pure math for the now-playing audio visualizer (docs/PARITY-ROADMAP.md §3):
/// collapse an FFT magnitude spectrum into display bars, apply peak-meter
/// ballistics frame-to-frame, and normalize for drawing. No CoreAudio, no FFT
/// engine, no UI — the audio tap and vDSP FFT live in a later, TCC-gated slice;
/// this is the CI-testable core that decides what the bars *do*. Clean-room.
enum VisualizerLogic {

    /// Average an FFT magnitude array into `bars` contiguous buckets. Bucketing is
    /// linear over the bins (log-frequency spacing is a future perceptual
    /// refinement, noted honestly). Returns `bars` zeros for an empty spectrum and
    /// `[]` for `bars <= 0`. When there are fewer bins than bars, each empty span
    /// falls back to its nearest bin so no bar is spuriously dead.
    static func bucket(magnitudes: [Double], bars: Int) -> [Double] {
        guard bars > 0 else { return [] }
        let binCount = magnitudes.count
        guard binCount > 0 else { return Array(repeating: 0, count: bars) }

        var output = [Double](repeating: 0, count: bars)
        for i in 0..<bars {
            let lo = i * binCount / bars
            let hi = (i + 1) * binCount / bars
            if hi > lo {
                var sum = 0.0
                for j in lo..<hi { sum += magnitudes[j] }
                output[i] = sum / Double(hi - lo)
            } else {
                output[i] = magnitudes[min(lo, binCount - 1)]
            }
        }
        return output
    }

    /// Peak-meter ballistics: each bar closes `attack` of the gap when rising and
    /// `release` of the gap when falling, so the visualizer snaps up to transients
    /// and decays smoothly (fast attack, slow release). `attack`/`release` are
    /// clamped to `0...1`. A length mismatch re-syncs by returning `target`.
    static func smoothed(
        previous: [Double],
        target: [Double],
        attack: Double,
        release: Double
    ) -> [Double] {
        guard previous.count == target.count else { return target }
        let a = min(1, max(0, attack))
        let r = min(1, max(0, release))
        return zip(previous, target).map { prev, tgt in
            let coefficient = tgt > prev ? a : r
            return prev + (tgt - prev) * coefficient
        }
    }

    /// Scale bars into `0...1` by a reference magnitude (e.g. a rolling peak).
    /// `reference <= 0` yields all zeros (silence / no reference yet).
    static func normalized(_ bars: [Double], reference: Double) -> [Double] {
        guard reference > 0 else { return bars.map { _ in 0 } }
        return bars.map { min(1, max(0, $0 / reference)) }
    }
}
