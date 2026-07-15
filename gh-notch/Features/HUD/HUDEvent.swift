import Foundation

/// A semantic media key, decoded from a raw `NSSystemDefined` event by
/// `HUDLogic.parseSystemDefinedKey`. Kept free of any AppKit/CGEvent type so the
/// whole decode path is pure and CI-testable (the roadmap's v0.6 §4 "CI can"
/// list). The interceptor (a later, hardware-gated slice) turns real events into
/// these; the pure logic decides everything downstream.
enum MediaKey: Equatable {
    case volumeUp
    case volumeDown
    case mute
    case brightnessUp
    case brightnessDown
    case keyboardBrightnessUp
    case keyboardBrightnessDown
}

/// One decoded key press: which key, whether it went down (vs up), and whether
/// it's an auto-repeat (held). The HUD reacts on down; up/repeat inform the
/// "did the value actually change?" safety check in the real interceptor.
struct HUDKeyPress: Equatable {
    let key: MediaKey
    let isDown: Bool
    let isRepeat: Bool
}

/// What the notch should render for a system HUD. `level` is the 0…1 scalar for
/// volume/brightness/keyboard backlight; `isMuted`/`isOn` cover the binary kinds.
/// `kind` reuses `HUDKind` (already wired into `NotchState`/`NotchStateMachine`),
/// so the model can map an event straight to `.hud(kind)`.
///
/// v0.6 core (docs/PARITY-ROADMAP.md §4). Clean-room from the roadmap's
/// behavioral description; no GPL reference opened (§9).
struct HUDEvent: Equatable {
    var kind: HUDKind
    /// 0…1, clamped. Meaningful for `.volume`/`.brightness`/`.keyboardBacklight`.
    var level: Double
    /// Volume only — a muted volume HUD shows the mute glyph, not the level.
    var isMuted: Bool
    /// On/off state for the binary kinds (`.capsLock`, `.charging`).
    var isOn: Bool
    /// Optional device label (e.g. the output device name for a volume change).
    var deviceName: String?

    init(
        kind: HUDKind,
        level: Double = 0,
        isMuted: Bool = false,
        isOn: Bool = false,
        deviceName: String? = nil
    ) {
        self.kind = kind
        self.level = min(1, max(0, level))
        self.isMuted = isMuted
        self.isOn = isOn
        self.deviceName = deviceName
    }
}
