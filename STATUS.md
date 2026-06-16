# STATUS — v0.2.0 Calendar feature

Living progress log. See PLAN.md for the design.

## Slices
- [ ] A. Pure core (CalendarEvent, CalendarPermission, CalendarLogic, CalendarFormatting) + tests
- [ ] B. Service layer (CalendarService, FakeCalendarService, EventKitCalendarService, CalendarModel) + tests
- [ ] C. UI (CalendarChip collapsed, CalendarAgendaView expanded, NotchView wiring)
- [ ] D. Wiring (entitlements, Info.plist usage strings, project.yml)
- [ ] E. Release prep (README roadmap, version bump to 0.2.0)
- [ ] F. Adversarial review + fixes
- [ ] G. Tag v0.2.0 + Release DMG

## Could NOT visually verify (no local Xcode)
_To be filled in as UI/EventKit code lands — these are compiled by CI but not behaviour-verified._

## Decisions / notes
- Mirrors the Battery feature pattern. All logic is in pure, CI-tested functions.
- Lazy calendar permission: requested on first expand, never at launch.
- App is not sandboxed; calendar entitlement added per the goal but inert without sandbox.
