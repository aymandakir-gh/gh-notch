# Changelog

All notable changes to gh-notch. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions are git tags (`vX.Y.Z`) and each tagged release ships a DMG built by CI. This file is permanent — the changelog never goes dark.

## [0.4.0] — 2026-07-13 — "The Morph"

The foundation rework everything after rides on (see `docs/PARITY-ROADMAP.md`).

### Added
- State-machine core: collapsed / peek / activity / HUD / expanded with priority rules (HUD > activity > peek, expanded outranks all), kind-tagged auto-dismiss timers, pin-aware collapse.
- Swipe gestures: two-finger swipe down opens, swipe up closes/dismisses; Magic Mouse supported (8× amplification); haptic tick on commit; momentum tails can never re-trigger.
- Multi-display: one panel per selected screen (built-in only, or all displays), drawn pill on notchless screens (185pt default), clamshell fallback, debounced rebuild on display changes.
- Settings tabs: General (launch at login, show-on displays, collapsed blend, hover delay, notch-width override), AI (unchanged), Features (per-section toggles; the status row stays on — it hosts the gear).
- Content-driven expanded height with a 60%-of-screen cap and internal scrolling; the fixed 410pt panel is gone.
- CHANGELOG.md (this file) and `docs/PARITY-ROADMAP.md` (the v0.4→v1.0 ladder).

### Changed
- The panel window is pre-sized to its maximum envelope and never resizes; expand/collapse is a pure SwiftUI spring morph (Reduce Motion falls back to a short fade). Hit-testing constrains events to the visible island so the envelope can't swallow clicks.
- BatteryMonitor is event-driven (IOKit power-source notifications + 5-minute safety poll; was a 30s poll). Calendar refreshes on `EKEventStoreChanged`. All models are `@MainActor`.
- Clicking a system permission dialog no longer collapses the panel from under it (click-away is pin-aware — a v0.2 bug).

### Fixed
- The stale in-repo Homebrew cask now points at the stable `releases/latest/download/gh-notch.dmg` asset instead of a 404ing v0.1.0 URL.

## [0.3.0] — 2026-07 — File Shelf

Drag files in to stage them (survives relaunch), drag out to Finder/apps, share/AirDrop per chip; 43 shelf tests; adversarial-review pass (21 findings fixed).

## [0.2.0] — 2026-07 — Calendar

Next event in the collapsed bar, today's agenda expanded; lazy EventKit permission (prompt only on expand); timezone-safe day windowing.

## [0.1.5] — 2026-06 — Polish

Real app icon, click-through collapsed placement, premium dropdown animation, command-bar live preview + new local commands (reverse, base64, percent-of).

## [0.1.0] — 2026-06 — Foundation

Notch panel above the menu bar (runtime-sampled geometry, no hardcoded models), AI command bar (local-first parse → optional OpenAI/Ollama-compatible endpoint, 🔒/☁️ provenance badges, Keychain-only key), battery HUD, clock, Settings; CI build+test+lint and tag→DMG release pipeline.
