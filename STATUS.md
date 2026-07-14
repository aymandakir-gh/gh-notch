# STATUS — v0.4.0 "The Morph"

Living progress log. See PLAN.md for the design, docs/PARITY-ROADMAP.md for the
v0.4→v1.0 ladder. (v0.1.x polish, v0.2.0 Calendar, v0.3.0 File Shelf shipped —
git history / CLAUDE.md.)

## Slices
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
