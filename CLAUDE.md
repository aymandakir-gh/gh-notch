# gh-notch — Claude Code working context

## What this is
**gh-notch** is a free, open-source macOS **notch utility** (SwiftUI + AppKit, macOS 14+, no Dock icon via `LSUIElement`). A borderless `NSPanel` lives at the notch:
- **Collapsed:** a thin menu-bar-level bar — **time to the left** of the camera, **battery to the right** (transparent, reads as part of the menu bar).
- **Expanded** (hover the notch, or click): a dropdown below the notch with an **AI command bar** (local-first; dispatches to a user-configured OpenAI/Ollama-compatible endpoint), **clock/date**, **battery**, and a **Settings** gear.
- Closes on Esc, click-outside, or when the pointer leaves (unless the command bar is in use).

## Your mission
Take it from "works but rough" to a **polished, genuinely useful, beautiful** notch app — NotchNook / Boring Notch quality.

**You can build and run this locally. Use that on every change.** The previous iterations were done blind through CI and converged slowly. Now: make a change → `xcodegen generate` → build → **run the app and look at the notch** → verify (screenshot / ask the user) → adjust. Do NOT stack multiple unverified visual changes; tighten the loop to one change at a time when it's visual.

## Build / run / test
Requires **full Xcode 16** (not just Command Line Tools) and:
```bash
brew install xcodegen swiftlint create-dmg librsvg
```
- The `.xcodeproj` is **generated** from `project.yml` and git-ignored — never commit it.
- Generate + open: `xcodegen generate && open gh-notch.xcodeproj`, then ⌘R.
- CLI build: `xcodebuild -scheme gh-notch -configuration Debug -destination 'platform=macOS' build`
- The app is `LSUIElement` (no Dock icon) — after launch, look at the **notch**.
- Tests: `xcodebuild test -scheme gh-notch -destination 'platform=macOS'` — keep them green.
- Lint: `swiftlint` — `force_unwrapping` is an **error**; no force-unwraps in non-test code.

## Architecture (key files)
- `gh-notch/App/` — `gh_notchApp.swift` (`@main`, Settings scene), `AppDelegate.swift` (accessory app, boots `NotchPanel`, re-positions on screen changes).
- `gh-notch/Notch/`
  - `NotchGeometry.swift` — samples `NSScreen.safeAreaInsets`/auxiliary areas for notch width+height; falls back to a top-center bar on non-notched displays. **Never hardcode pixel sizes.**
  - `NotchPanel.swift` — borderless non-activating `NSPanel` at `.screenSaver` level; `MouseAwareHostingView` (tracking area → auto-collapse on mouse-exit); click-away monitor.
  - `NotchViewModel.swift` — `@Observable`; computes collapsed (flanks the notch) and expanded (centered dropdown) frames; `pinnedOpen` keeps it open while typing.
  - `NotchView.swift` — SwiftUI root: collapsed flanking status + expanded surface.
- `gh-notch/Features/CommandBar/` — `ArithmeticEvaluator`, `CommandParser` (local commands: math, count/wc, upper/lower, date, help), `AIEndpoint`, `SecretStore` (Keychain), `SettingsStore` (UserDefaults + Keychain), `AIDispatcher` (OpenAI-compatible `/chat/completions`), `CommandBarView/ViewModel`.
- `gh-notch/Features/Battery/` — IOKit power source → `BatterySnapshot`. `gh-notch/Features/Clock/` — time/date.
- `gh-notch/Settings/SettingsView.swift` — AI endpoint config (⌘,).
- `gh-notchTests/` — unit tests (geometry math, parser, dispatcher via stub URLProtocol, etc.).

## Current state (v0.2.0)
Calendar feature (v0.2.0): `Features/Calendar/` mirrors the Battery pattern — `CalendarService`
protocol (`EventKitCalendarService` + `FakeCalendarService`), pure `CalendarLogic`/`CalendarFormatting`
(fully unit-tested: sorting, timezone day-windowing, relative formatting, en_IT 24h), and an
`@Observable @MainActor CalendarModel` (lazy permission, requested on expand). UI: a collapsed
next-event chip + an expanded "Today" agenda with empty/denied states. NSCalendars(FullAccess)UsageDescription
+ a calendar entitlement are wired. EventKit access is requested only when the panel is expanded.

### Previous state (v0.1.5)
Functional: flanking collapsed status, hover/click open, auto-hide, command bar (local + remote), Settings, battery, clock. CI (build+test+lint) and Release (tag `v*` → DMG → Homebrew tap `aymandakir-gh/tap`) pipelines work. DMG is **unsigned** (right-click → Open) until there's a paid Apple Developer account — see `RELEASING.md`.

v0.1.5 polish pass shipped: real app icon (generated in `tools/AppIconGenerator/`); tighter, click-through collapsed placement (`sideWidth = 96`); premium dropdown (drop-from-notch animation, softer corners, gear hover, consistent rounded/monospaced numerals); command bar with live on-device preview, copy button, empty-state hint chips, and new local commands (reverse, base64/unbase64, `<n>% of <m>`). Also fixed: xcodegen Info.plist version clobber, so the DMG reports `MARKETING_VERSION`.

## Known rough edges — improve, verifying each visually
1. The collapsed click-through (only the time/battery are interactive; empty flanks pass clicks to the menu bar) is reasoned-correct but not yet verified on a real notched display — confirm it when a build is runnable.
2. Real features (roadmap): media controls / now-playing, calendar next-event (EventKit, lazy permission), file shelf (drag-drop + AirDrop), system HUD.

## Rules
- Conventional commits; push to `main` (CI runs). Release by pushing a tag (`v0.1.5`, …) → Release workflow builds the DMG.
- No force-unwraps; tests green; SwiftLint clean; runtime notch geometry sampled, not hardcoded.
- **Privacy-first:** local commands never leave the device; remote queries go only to the user's configured endpoint.
- After any visual change: generate → build → **run → verify** before continuing.
