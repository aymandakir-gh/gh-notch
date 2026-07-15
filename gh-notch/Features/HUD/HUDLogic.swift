import Foundation

/// Pure HUD math and NX-key decoding — no CGEvent, no AppKit, no I/O. Everything
/// the HUD model computes lives here so it's exhaustively CI-testable (the
/// roadmap's v0.6 §4 "CI can" list). Clean-room from the published bit-layout in
/// docs/PARITY-ROADMAP.md §4; no GPL source opened (§9).
enum HUDLogic {

    // MARK: NX system-defined key decoding

    /// `NX_KEYTYPE_*` codes carried in the high word of a system-defined event's
    /// `data1`. Named constants so the mapping reads against Apple's header.
    private enum NXKey {
        static let soundUp = 0
        static let soundDown = 1
        static let brightnessUp = 2
        static let brightnessDown = 3
        static let mute = 7
        static let illuminationUp = 21   // keyboard backlight up
        static let illuminationDown = 22 // keyboard backlight down
    }

    /// Decode one `NSSystemDefined` event's `data1` into a media-key press, or
    /// `nil` when it isn't a media key we handle. Layout (Apple's convention):
    /// `keyCode = (data1 >> 16) & 0xFFFF`; the low word holds `keyFlags` where
    /// `(keyFlags >> 8) & 0xFF` is `0x0A` for down / `0x0B` for up and bit 0 is
    /// the auto-repeat flag. Non-key subtypes and unknown codes return `nil`.
    static func parseSystemDefinedKey(data1: Int) -> HUDKeyPress? {
        guard data1 >= 0 else { return nil }
        let keyCode = (data1 & 0xFFFF_0000) >> 16
        let keyFlags = data1 & 0x0000_FFFF
        let keyState = (keyFlags & 0xFF00) >> 8
        let isRepeat = (keyFlags & 0x1) == 1

        let isDown: Bool
        switch keyState {
        case 0x0A: isDown = true
        case 0x0B: isDown = false
        default: return nil
        }

        guard let key = mediaKey(forCode: keyCode) else { return nil }
        return HUDKeyPress(key: key, isDown: isDown, isRepeat: isRepeat)
    }

    private static func mediaKey(forCode code: Int) -> MediaKey? {
        switch code {
        case NXKey.soundUp: return .volumeUp
        case NXKey.soundDown: return .volumeDown
        case NXKey.mute: return .mute
        case NXKey.brightnessUp: return .brightnessUp
        case NXKey.brightnessDown: return .brightnessDown
        case NXKey.illuminationUp: return .keyboardBrightnessUp
        case NXKey.illuminationDown: return .keyboardBrightnessDown
        default: return nil
        }
    }

    /// Which HUD a media key drives (so the interceptor can pick the kind without
    /// re-switching on the raw code).
    static func hudKind(for key: MediaKey) -> HUDKind {
        switch key {
        case .volumeUp, .volumeDown, .mute: return .volume
        case .brightnessUp, .brightnessDown: return .brightness
        case .keyboardBrightnessUp, .keyboardBrightnessDown: return .keyboardBacklight
        }
    }

    // MARK: Level presentation

    /// Filled segment count `0…total` for a 0…1 level (rounded to nearest), the
    /// way macOS renders volume/brightness as ~16 blocks. `level` is clamped;
    /// `total <= 0` yields 0.
    static func filledSegments(level: Double, total: Int) -> Int {
        guard total > 0 else { return 0 }
        let clamped = min(1, max(0, level))
        let filled = Int((clamped * Double(total)).rounded())
        return min(total, max(0, filled))
    }

    /// Whether the glow theme should tip from its base color toward the hot end.
    /// The roadmap ramps green→red past 80%, so levels strictly above `threshold`
    /// read as `.hot`; at or below it, `.normal`.
    enum GlowStage: Equatable { case normal, hot }
    static func glowStage(level: Double, threshold: Double = 0.8) -> GlowStage {
        min(1, max(0, level)) > threshold ? .hot : .normal
    }

    /// `"0%"…"100%"` for the level label (clamped, rounded to nearest percent).
    static func percentText(level: Double) -> String {
        let clamped = min(1, max(0, level))
        return "\(Int((clamped * 100).rounded()))%"
    }

    // MARK: Step size

    /// Volume/brightness step per key press: the normal `1/16` grid, or the
    /// `1/64` fine grid when Option+Shift is held (Apple's fine-adjust chord).
    static func step(fine: Bool) -> Double {
        fine ? 1.0 / 64.0 : 1.0 / 16.0
    }

    // MARK: Coalescing

    /// Collapse a burst of events to the latest per kind, preserving the order in
    /// which each kind first appeared. A flurry of volume-key repeats (plus, say,
    /// one brightness tap) becomes one volume HUD carrying the final level and one
    /// brightness HUD — never twenty presentations.
    static func coalesceLatestPerKind(_ events: [HUDEvent]) -> [HUDEvent] {
        var order: [HUDKind] = []
        var latest: [HUDKind: HUDEvent] = [:]
        for event in events {
            if latest[event.kind] == nil { order.append(event.kind) }
            latest[event.kind] = event
        }
        return order.compactMap { latest[$0] }
    }
}
