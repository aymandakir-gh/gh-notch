# PLAN — v0.4.0 "The Morph": Foundation Rework

Full context: `docs/PARITY-ROADMAP.md` §2 (the v0.4→v1.0 Alcove-parity ladder). This
milestone replaces the Bool/dual-animation/single-screen substrate with a
spring-driven, state-machine, multi-display panel architecture. Only user-facing
additions: swipe gestures, the no-notch/multi-display pill, Settings tabs +
launch-at-login. Judged on feel; every later milestone rides on it.

## Verification reality (v0.4)
Full Xcode is NOT installed on this machine (CommandLineTools only — the CLAUDE.md
"build and run locally" note was aspirational). Loop per slice:
1. `tools/typecheck.sh` — full `swiftc -typecheck` of the app module against the
   CLT macOS SDK (NEW, this milestone; upgrades the old parse-only check).
2. `xcodegen generate` sanity.
3. Commit → push → CI green (build + tests + lint on GitHub runners).
Visual behaviors that CI can't exercise go into STATUS.md's "needs visual
verification" ledger, burned down when a runnable build is available.

## Architecture

### A. Pure core (state machine + layout math + motion table)
- `Notch/NotchState.swift` — `enum NotchState: Equatable`:
  `collapsed`, `peek(PeekContent)`, `activity(ActivityID)`, `hud(HUDKind)`,
  `expanded`. `PeekContent`/`ActivityID`/`HUDKind` are minimal placeholder value
  types now (real payloads land in v0.6/v0.7) so the machine + layout are final.
- `Notch/NotchEvent.swift` — `enum NotchEvent`: `hoverEnter`, `hoverExit`, `tap`,
  `swipe(SwipeDirection)`, `escape`, `clickAway`, `activityPosted(ActivityID)`,
  `activityDismissed(ActivityID)`, `hudEvent(HUDKind)`, `timeout(TransientKind)`.
- `Notch/NotchStateMachine.swift` — pure transition table
  `transition(_ state: NotchState, _ event: NotchEvent, pinned: Bool) -> NotchTransition`
  where `NotchTransition = (next: NotchState, autoDismiss: Duration?)`.
  Priority: hud > activity > peek; `expanded` pins over all transients; transients
  auto-dismiss after injected durations (`hud: 1.5s`, `peek: 2s`, `activity: 5s` —
  constants in one place). `pinned` suppresses hoverExit/clickAway collapse.
- `Notch/PinReason.swift` — `enum PinReason: Hashable` (`commandBar`,
  `permissionDialog`, `shelfDrag`); `Set<PinReason>` replaces the OR-chain in
  `NotchView.syncPinnedOpen()`.
- `Notch/NotchLayout.swift` — pure frame math, extracted from
  `NotchViewModel.currentFrame`:
  `panelFrame(geometry:) -> NSRect` (the ONE pre-sized max frame),
  `islandFrame(state:geometry:contentHeight:) -> NSRect` (the drawn island's rect
  within the panel, per state). Expanded height = measured content, capped at
  60% of screen visible height. Replaces the fixed `expandedSize = 380×410`.
- `Notch/NotchMotion.swift` — single source of truth: spring per transition pair
  (default `.spring(response: 0.36, dampingFraction: 0.8)`), durations, reduce-motion
  variants. No more scattered `0.20`/`0.22`/`0.12` literals.

### B. Panel & animation unification
- `NotchPanel` becomes pre-sized to `NotchLayout.panelFrame` (max rect), NEVER
  resized on expand/collapse. Delete `applyCurrentFrame(animated:)`'s
  `NSAnimationContext` path and the `onLayoutChange` re-frame; the morph is 100%
  SwiftUI inside the fixed panel.
- `Notch/NotchShape.swift` — custom `Shape`, continuous-corner island (square top,
  rounded bottom), `animatableData` over width/height/corner radii. The visible
  black surface for EVERY state — collapsed draws the notch extension (or pill on
  no-notch displays).
- `NotchViewModel` rewritten: owns `state: NotchState` + `pinReasons`, forwards
  events to the machine, exposes `islandSize(for:)`; `@MainActor @Observable`.
  `BatteryMonitor`/`ClockModel` gain `@MainActor` for isolation consistency.
- Hit-testing: panel keeps `ignoresMouseEvents = false`; the SwiftUI content
  applies `contentShape` only over the island + interactive flanks so collapsed
  empty flanks stay click-through (preserve v0.3 behavior).
- `blendCollapsed` setting (default ON = current transparent look; OFF = drawn
  pill/island collapsed) — the drawn look is the morph-capable one; keep both.

### C. Sections (content-driven expanded surface)
- `Notch/NotchSection.swift` — `protocol NotchSection: Identifiable` with
  `placement` (`.collapsedLeading` / `.collapsedTrailing` / `.expanded(order:)`),
  `isEnabled` (SettingsStore-backed toggle), `body(context:) -> AnyView`.
- Adapters for existing features: CommandBarSection, CalendarSection,
  ShelfSection, StatusRowSection (clock+battery+gear). `NotchView` becomes a
  state-switch + section iterator; expanded surface is a `ScrollView` +
  `VStack` of enabled sections, height measured via `onGeometryChange`, capped.
- Per-feature toggles appear in Settings → Features.

### D. Gesture layer
- `Notch/GestureRecognizerLogic.swift` — pure: feed
  `(deltaX, deltaY, phase, momentumPhase, hasPreciseDeltas, timestamp)` tuples →
  emits `SwipeDirection?`. Axis dominance ≥1.5×, activation ≥4pt accumulated,
  0.2pt noise floor, 8× amplification for non-precise (Magic Mouse) deltas,
  lifecycle idle→tracking→committed(fire once)→drain until momentum ends or
  300ms silence. The momentum re-trigger bug is the #1 slice-G target.
- `Notch/GestureMonitor.swift` — local `.scrollWheel` monitor scoped to events
  inside the panel; feeds the recognizer; haptic
  (`NSHapticFeedbackManager…perform(.levelChange…)`) on commit. No permissions.
- Bindings: down = expand (later: cycle activities), up = collapse/dismiss,
  horizontal = reserved (v0.5 track skip). Cleanroom rule: GPL notch apps'
  gesture sources stay CLOSED while writing this (docs/PARITY-ROADMAP.md §9).

### E. Multi-display + pill + Settings
- `Notch/PanelManager.swift` — owns one `NotchPanel` + `NotchViewModel` per
  `NSScreen` (per setting), full teardown/rebuild on
  `didChangeScreenParametersNotification` (ghost-window prevention).
  `AppDelegate` shrinks to booting the manager.
- Per-screen `NotchGeometry` (drop the menu-bar-screen-only assumption): notched
  screens use sampled notch; others a drawn pill (fallbackWidth 185, was 220 —
  research-verified default), `notchWidthOverride` gets Settings UI.
- Settings → `TabView`: General (launch-at-login via `SMAppService.mainApp`,
  show-on displays, collapsed style, hover dwell 100–300ms), AI (existing form,
  unchanged — differentiator contract), Features (section toggles).
- Efficiency in the same pass: battery polling → IOKit
  `IOPSNotificationCreateRunLoopSource`; calendar refresh on `.EKEventStoreChanged`
  instead of blind polls; clock ticks pause while nothing visible shows time.
- Fix stale `Casks/gh-notch.rb` (points at 0.1.0 — would 404): regenerate or
  remove until signing (v0.5 decision) lands.

### F/G/H. Release prep → adversarial review → tag
- F: README (features/roadmap/GIF placeholders), MARKETING_VERSION 0.4.0,
  CHANGELOG.md started.
- G: adversarial review across ≥5 dimensions (hit-testing/click-through, state
  machine edge cases, gesture momentum, multi-display races, Observable churn in
  animated subtree) + regression tests per confirmed finding.
- H: tag v0.4.0 → Release workflow DMG.

## Differentiator contract (regression-guarded every slice)
Local-first `submit()` ordering; `previewLocal()` never networks; 🔒/☁️ badges;
Keychain-only keys; no telemetry. Existing tests must stay green untouched.

## Test targets (CI)
StateMachine: exhaustive event×state table incl. pinned suppression, transient
auto-dismiss, priority preemption (hud over peek etc.), invalid-event no-ops.
NotchLayout: panel/island frames per state × (notch, no-notch, override,
tall-content cap). GestureRecognizerLogic: commit thresholds, axis dominance,
momentum drain (no double-fire), Magic Mouse amplification, noise rejection.
Sections: ordering, toggle filtering. SettingsStore: new keys + migration.
PinReason set semantics. Existing suites untouched-green.
