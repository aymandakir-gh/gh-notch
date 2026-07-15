# STATUS — v0.5.0 "Now Playing" (in progress) · v0.4.0 "The Morph" (shipped)

Living progress log. See PLAN.md for the design, docs/PARITY-ROADMAP.md for the
v0.4→v1.0 ladder. (v0.1.x polish, v0.2.0 Calendar, v0.3.0 File Shelf, v0.4.0
The Morph shipped — git history / CLAUDE.md / tags.)

## v0.5 — Now Playing (PARITY-ROADMAP §3)
- [x] A. Pure core (no I/O, CI-testable, clean-room per §9 — no GPL source opened):
       `Features/NowPlaying/` — `NowPlayingState` (pure snapshot, `hasTrack`/
       `trackIdentity`, elapsed/duration clamped ≥0); `NowPlayingLogic`
       (playing-only elapsed interpolation clamped to duration + no-rewind on
       clock skew; `progress`; `m:ss`/`h:mm:ss` `timeLabel`; wrap-around
       `marqueeOffset` (0 when text fits / speed≤0 / container≤0); per-track
       `artworkCacheKey` stable across scrub/pause — pre-empts Alcove's
       dominant-color CPU leak; tolerant adapter JSON-line `parse` → optional-field
       `NowPlayingPayload` (nil only on non-object; `{}`→empty; numbers-as-strings;
       rate→playing; bad base64 drops only artwork) + diff-mode `applying` merge);
       `NowPlayingSource` protocol (`updates: AsyncStream` + `probe()`) +
       `FakeNowPlayingSource`. Tests: `NowPlayingLogicTests` (28),
       `NowPlayingStateTests` + `FakeNowPlayingSourceTests`. `typecheck.sh` 52
       files OK locally; XCTest gated to CI.
- [x] B (pure part). `NowPlayingSourceSelection` — pure fallback-chain policy:
       `NowPlayingBackend` (adapter→direct→appleScript); `select`/`reselect`
       (prefer top-of-chain available; recovery == failover); `directMediaRemote-
       Eligible` (< 15.4). 9 tests, verified via swift (b4e23ec).
- [ ] B (gated part). `NowPlayingModel` (@MainActor @Observable) real backends:
       subprocess supervision, capture-time tracking, artwork cache, control
       routing. **Needs a runnable build + the signing/spend gate (Apple Developer
       $99 — Ayman's approval).**
- [ ] C–H. peek/expanded player + visualizer views, section wiring, adversarial
       review, tagged DMG. Visual/private-API work blocked on Xcode.app (this
       machine is CLT-only) + signing decision.

## v0.6 — HUD replacement (PARITY-ROADMAP §4)
- [x] A. Pure core (clean-room, CI-testable, §9): `Features/HUD/` — `HUDEvent` +
       `MediaKey` + `HUDKeyPress`; `HUDLogic` = `parseSystemDefinedKey` (NX `data1`
       bit-math: keyCode>>16, state 0x0A down/0x0B up, bit0 repeat → media key;
       nil on unknown code / bad state / negative), `hudKind(for:)`,
       `filledSegments` (rounded/clamped/guards total≤0), `glowStage` (green→red
       past 80%), `percentText`, `step` (1/16 or 1/64 fine), `coalesceLatestPerKind`
       (burst→1/kind). `HUDLogicTests` (all 7 codes + up/repeat/unknown/bad/neg,
       kind map, segment rounding, glow, percent, step, coalesce). Reuses existing
       `HUDKind`. typecheck 54 files OK; bit-math cross-checked via swiftc.
- [x] A2. `InterceptSafety` — pure per-key-class fail-safe: a swallowed key with
       no value change (and not at a rail) counts as a failure; two in a row backs
       off interception for that class until device-change/tap re-arm, so the user
       can never be locked out of volume. at-rail no-ops immune. 7 tests, verified
       via swift (db4dcfd).
- [ ] B–H. MediaKeyInterceptor (CGEvent tap — **Accessibility TCC-gated**),
       Audio/Brightness/CapsLock/Privacy sources (CoreAudio public + DisplayServices
       private via dlopen), HUD views. Hardware + AX-gated → later slices.

## v0.7 — Live Activity engine (PARITY-ROADMAP §5)
- [x] A. Pure core (clean-room, CI-testable, §5 is ~70% this): `Features/Activities/`
       — `Activity` (kind/priority/title/progress/postedAt/expiresAt/DismissBehavior,
       clamped progress); `ActivityCenterLogic` (`ordered` priority desc→recency→id;
       `frontmost` = active[cycleIndex]; `posting` coalesce+revive+preempt;
       `cycled` wrap; `dismissingFrontmost` remove|restorable + clamp; `expiring`
       hard-deadline keep-sticky; `restoring` = explicit focus-the-item). Times are
       injected `TimeInterval`, no `Date`. `ActivityCenterLogicTests` (23 incl.
       preemption both ways, cycle wrap+reset, dismiss/restore/revive, expiry clamp).
       CI caught + fixed a restore-focus ambiguity (f2480c7). typecheck 56 files OK.
- [x] (synergy, ahead of §8.2) `Features/Activities/TimerParsing.swift` — pure
       offline `timer 10m coffee` → (duration, label) parser feeding the future
       TimerProvider + AI-bar. Attached/bare/spaced/long units, 24h clamp,
       keyword-gated. `TimerParsingTests`. Behaviorally verified: real source
       compiled standalone via `swift` against 19 cases (25ab3ec, CI green).
- [ ] B–H. `@MainActor @Observable ActivityCenter` shell + providers (battery/
       device/focus/timer/download/screenRec/calendar) — source-gated later slices.

## v0.4 Slices
- [x] 0. Docs prep: PARITY-ROADMAP.md into docs/, PLAN/STATUS reset, CLAUDE.md
       verification-reality fix, tools/typecheck.sh (36 files OK locally)
- [x] A. Pure core: NotchState/NotchEvent/NotchStateMachine/PinReason/NotchLayout/
       NotchMotion + 2 test suites (machine table incl. stale-timer/pin/priority
       sweep; layout envelope/island/cap/pill/override)
- [x] B. Panel & animation unification: pre-sized panel, NotchShape, ViewModel on
       the state machine, SwiftUI-only morph, hitTest interactive rects — CI green
- [x] C. Section registry (enum + pure SectionsLogic) + AppSettingsStore toggles
       + content-driven expanded height — CI green
- [x] D. Gestures: GestureRecognizerLogic (14 synthetic-stream tests) +
       GestureMonitor + haptics — CI green
- [x] E. Multi-display PanelManager (pure DisplaySelection + tests) + pill 185pt +
       Settings tabs + launch-at-login + event-driven battery/calendar
- [x] F. Release prep: README roadmap restructure, 0.4.0, CHANGELOG.md started,
       cask → stable latest/download URL (was 404ing 0.1.0)
- [x] G. Adversarial review (3 dimensions: state-machine/viewmodel, layout/
       geometry/multi-display, gestures/sections/parsers) — **zero live defects**
       after fixes below. `AdversarialReviewTests.swift` added (non-finite content
       height, panel-envelope click-through rects, stale-timeout clock survival,
       momentum-during-drain, multi-display/section edge cases). Fixed:
       (1) `hoverDwell` setter now clamps to [0,0.5] like load (+regression in
       `AppSettingsStoreTests`); (2) `NotchLayout` treats NaN content height as
       zero so expanded island never becomes non-finite; (3) `NotchViewModel`
       re-arms the dismiss clock when a stale `timeout` would orphan a transient.
       Two latent items documented below (wide-notch expanded width, dead
       `repositionToActiveScreen`).
- [ ] H. Tag v0.4.0 → DMG release

## Needs visual verification (no runnable build on this machine — burn down when
## Xcode is available; carried from v0.3 where noted)
- (carried v0.3) drag-IN/drag-OUT real Finder drops; AirDrop picker anchoring;
  410pt panel non-clipping; real Application-Support staging dir
- (carried v0.1.5) collapsed click-through on a real notched display

## Decisions / notes
- 2026-07-14: Slice G latent findings (NOT live in v0.4 — recorded so they aren't lost):
  - **Wide-notch expanded width** (`NotchLayout.islandSize`): for `notchWidth > 204`
    a transient island computes WIDER than expanded, breaking the
    collapsed≤transient≤expanded invariant. Unreachable today (peek/hud/activity are
    never posted in v0.4) and it CONFLICTS with the deliberate
    `testWiderNotchThanExpandedSurfaceWidensTheExpandedIsland` (expanded == notchWidth).
    **Defer the design call to v0.5** (when transients ship): decide whether expanded
    should track notchWidth or floor at `notchWidth + 2·transientWingWidth`, then
    reconcile the two tests.
  - **`NotchPanel.repositionToActiveScreen()` is dead code** (no caller; grep-confirmed).
    Harmless now, but a multi-monitor foot-gun if wired into the `.all` flow — remove or
    fix when multi-display placement is next touched.
- 2026-07-13: Confirmed CommandLineTools-only on this machine (no Xcode.app).
  Added tools/typecheck.sh (full swiftc -typecheck vs CLT SDK) — stronger than
  the v0.1–v0.3 parse-only loop; XCTest still CI-only.
