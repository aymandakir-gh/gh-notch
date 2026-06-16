# PLAN — v0.2.0 Calendar feature

Adds a Calendar feature to gh-notch, mirroring the Battery feature's shape
(value type + protocol-backed service with an injectable fake + pure testable
logic + `@Observable` model + SwiftUI view). One feature only this pass.

## Verification reality
No local Xcode in this environment. Strategy: push **all** behaviour into pure,
unit-tested functions the CI runs; keep EventKit + SwiftUI as thin, isolated
mounts. Every non-trivial behaviour ships with a passing test. The EventKit
service and the SwiftUI views are the only pieces CI can compile-but-not-behaviour-verify;
they are listed explicitly in STATUS.md under "could not visually verify".

## Architecture (mirrors Features/Battery)
- `CalendarEvent` — pure value type (`id, title, start, end, isAllDay`). No EventKit/SwiftUI.
- `CalendarPermission` — `enum { notDetermined, denied, granted }`. Pure.
- `CalendarService` — protocol: `authorization`, `requestAccess() async`, `events(for:)`.
  - `EventKitCalendarService` — real impl (EventKit). Maps `EKAuthorizationStatus`→`CalendarPermission`
    and `EKEvent`→`CalendarEvent`. THIN; the only headless-untestable code.
  - `FakeCalendarService` — canned permission + events. Ships in the app target so it powers
    both SwiftUI previews and the unit tests (this is the "FakeCalendarService for tests").
- `CalendarLogic` — pure: `agenda(from:now:calendar:)` (filter to the day containing `now`,
  in the injected calendar's timezone, then sort), `sorted` (all-day first, then by start, then
  title), `nextEvent(_:now:)` (earliest timed event not yet ended; all-day events never become
  the collapsed "next").
- `CalendarFormatting` — pure: `relative(...)` → "now"/"ended"/"all day"/"in 15m"/"in 1h 5m"/"in <1m";
  `compact(...)` (collapsed; drops the "in " prefix); `time(_:locale:timeZone:)` using template "jmm"
  (respects locale hour-cycle → 24h under en_IT). All take explicit `now`/`locale`/`timeZone` so they
  are deterministic and timezone/locale-testable.
- `CalendarModel` — `@Observable @MainActor`: injects `CalendarService`, `Calendar`, `now`. Holds
  `permission`, `agenda`; computes `nextEvent`. `start()` = initial refresh + 60s poll (NO prompt).
  `requestAccess() async` = prompt only if notDetermined, then refresh (called when the user EXPANDS —
  lazy permission, never at launch). `refresh()` re-reads authorization (catches System Settings
  changes) and re-fetches when granted.

## UI (isolated, minimal)
- Collapsed: a compact `CalendarChip` (calendar glyph + compact relative, e.g. "15m") added to the
  LEFT flank beside the time, shown only when permission == granted and there is a next event.
  `sideWidth` 96 → 120 so time + chip fit; click-through (from v0.1.5) keeps the wider footprint from
  eating menu-bar clicks. Symmetric, so the notch stays centred.
- Expanded: a `CalendarAgendaView` section (header "Today" + scrollable rows: time + title, ended rows
  dimmed) between the command bar and the clock/battery row. `expandedSize.height` 172 → 248 to fit.
  Empty → "No events today". Denied → "Calendar access off" + a button that opens System Settings.
  notDetermined → access is requested on expand.

## Wiring
- `project.yml` info.properties: `NSCalendarsUsageDescription` + `NSCalendarsFullAccessUsageDescription`
  (the latter is required by macOS 14 `requestFullAccessToEvents`). Added to info.properties (not the
  generated Info.plist) so xcodegen stays idempotent.
- Entitlement: new `gh-notch/Resources/gh-notch.entitlements` with
  `com.apple.security.personal-information.calendars`, wired via `CODE_SIGN_ENTITLEMENTS`. NOTE: the app
  is NOT sandboxed, so this entitlement is inert today (only the usage strings are strictly required);
  it is added per the goal and to be correct if the app is ever sandboxed. App Sandbox is deliberately
  NOT enabled (would break the AI network dispatch).
- EventKit auto-links via `import EventKit` (no explicit project linking needed for system frameworks).
- `MARKETING_VERSION` 0.1.5 → 0.2.0. Verify Info.plist stays idempotent and version is not clobbered.

## Slices (each: parse-check → commit → push → CI green)
- A. Pure core: CalendarEvent, CalendarPermission, CalendarLogic, CalendarFormatting + full tests.
- B. Service layer: CalendarService + FakeCalendarService + EventKitCalendarService + CalendarModel
     + model tests (permission states via fake) + EK status-mapping test.
- C. UI: CalendarChip, CalendarAgendaView, wire into NotchView (sideWidth, expandedSize, mounts).
- D. Wiring: entitlements + Info.plist usage strings + project.yml; verify xcodegen idempotent.
- E. Release prep: README roadmap (Calendar ✅), version bump, STATUS.md.
- F. Adversarial review of the diff → fix confirmed findings.
- G. Tag v0.2.0 → Release builds DMG → verify.

## Test coverage targets (pure, CI-run)
sorting (all-day first / by start / title tiebreak); agenda day-window filtering in Europe/Rome tz
(an event at 23:30 Rome is "today"); next-event selection (skips all-day, skips ended, picks earliest);
relative "now"/"ended"/"all day"/"in 15m"/"in 1h"/"in 1h 5m"/"in <1m"; compact form; time formatting
24h under en_IT and 12h under en_US; timezone-dependent time text; permission states notDetermined/
denied/granted driving model.agenda + model.permission via the fake; EKAuthorizationStatus mapping.
