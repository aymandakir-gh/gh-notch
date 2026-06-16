# STATUS — v0.2.0 Calendar feature

Living progress log. See PLAN.md for the design.

## Slices
- [x] A. Pure core (CalendarEvent, CalendarPermission, CalendarLogic, CalendarFormatting) + tests — CI green
- [x] B. Service layer (CalendarService, FakeCalendarService, EventKitCalendarService, CalendarModel) + tests — CI green
- [ ] C. UI (CalendarChip collapsed, CalendarAgendaView expanded, NotchView wiring)
- [ ] D. Wiring (entitlements, Info.plist usage strings, project.yml)
- [ ] E. Release prep (README roadmap, version bump to 0.2.0)
- [ ] F. Adversarial review + fixes
- [ ] G. Tag v0.2.0 + Release DMG

## Could NOT visually verify (no local Xcode) — compiled by CI, behaviour not exercised
- `EventKitCalendarService`: the live EventKit store/fetch and the real macOS permission
  prompt (`requestFullAccessToEvents`). Only the `EKAuthorizationStatus → CalendarPermission`
  mapping is unit-tested; the EKEvent fetch/predicate path needs a real calendar + TCC.
- (UI pieces will be added here in slice C.)

## Decisions / notes
- Mirrors the Battery feature pattern. All logic is in pure, CI-tested functions.
- Lazy calendar permission: requested on first expand, never at launch.
- App is not sandboxed; calendar entitlement added per the goal but inert without sandbox.
