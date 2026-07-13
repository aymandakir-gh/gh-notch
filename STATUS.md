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
- [ ] B. Panel & animation unification: pre-sized panel, NotchShape, ViewModel on
       the state machine, SwiftUI-only morph
- [ ] C. Section registry + content-driven expanded height (ScrollView, cap)
- [ ] D. Gestures: GestureRecognizerLogic (pure) + GestureMonitor + haptics
- [ ] E. Multi-display PanelManager + no-notch pill + Settings tabs +
       launch-at-login + poll→notification cleanups
- [ ] F. Release prep: README, 0.4.0, CHANGELOG.md
- [ ] G. Adversarial review + fixes + regression tests
- [ ] H. Tag v0.4.0 → DMG release

## Needs visual verification (no runnable build on this machine — burn down when
## Xcode is available; carried from v0.3 where noted)
- (carried v0.3) drag-IN/drag-OUT real Finder drops; AirDrop picker anchoring;
  410pt panel non-clipping; real Application-Support staging dir
- (carried v0.1.5) collapsed click-through on a real notched display

## Decisions / notes
- 2026-07-13: Confirmed CommandLineTools-only on this machine (no Xcode.app).
  Added tools/typecheck.sh (full swiftc -typecheck vs CLT SDK) — stronger than
  the v0.1–v0.3 parse-only loop; XCTest still CI-only.
