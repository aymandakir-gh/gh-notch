# STATUS — v0.2.0 Calendar feature

Living progress log. See PLAN.md for the design.

## Slices
- [x] A. Pure core (CalendarEvent, CalendarPermission, CalendarLogic, CalendarFormatting) + tests — CI green
- [x] B. Service layer (CalendarService, FakeCalendarService, EventKitCalendarService, CalendarModel) + tests — CI green
- [x] C. UI (CalendarChip collapsed, CalendarAgendaView expanded, NotchView wiring) — CI green
- [x] D. Wiring (entitlements, Info.plist usage strings, project.yml) — CI green
- [x] E. Release prep (README roadmap, version bump to 0.2.0) — in this commit
- [ ] F. Adversarial review + fixes
- [ ] G. Tag v0.2.0 + Release DMG

## Could NOT visually verify (no local Xcode) — compiled by CI, behaviour not exercised
- `EventKitCalendarService`: the live EventKit store/fetch and the real macOS permission
  prompt (`requestFullAccessToEvents`). Only the `EKAuthorizationStatus → CalendarPermission`
  mapping is unit-tested; the EKEvent fetch/predicate path needs a real calendar + TCC.
- Collapsed `CalendarChip` placement next to the time (sideWidth widened 96 → 124) — fits in
  reasoning but not pixel-verified; confirm it doesn't crowd the time or overlap the notch.
- Expanded `CalendarAgendaView` layout and the fixed panel height (expandedSize 172 → 260):
  no clipping vs. whitespace balance is unverified; the denied-state "Open System Settings"
  deep link is not click-tested.
- Whether the macOS calendar permission prompt actually appears on first expand, and the
  granted agenda renders, can only be confirmed on a real machine / the release DMG.
- The `EKAuthorizationStatus.authorized` case triggers a deprecation warning in the app build
  (kept intentionally to map legacy grants to `.granted`); warning only, CI stays green.

## Decisions / notes
- Mirrors the Battery feature pattern. All logic is in pure, CI-tested functions.
- Lazy calendar permission: requested on first expand, never at launch.
- App is not sandboxed; calendar entitlement added per the goal but inert without sandbox.
