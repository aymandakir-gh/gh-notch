# STATUS — v0.3.0 File Shelf

Living progress log. See PLAN.md for the design. (v0.1.x polish and v0.2.0 Calendar
already shipped — see git history / CLAUDE.md.)

## Slices
- [ ] A. Pure core (ShelfItem, ShelfLogic, FileMetadata) + tests
- [ ] B. Service + store (FileSource, DiskFileSource, FakeFileSource, ShelfStore) + tests (≥30 total)
- [ ] C. ShelfView (chips + remove + clear-all + empty state) mounted in the expanded panel
- [ ] D. Drag-IN (.dropDestination)
- [ ] E. Drag-OUT (.onDrag) + NSSharingServicePicker share (AirDrop)
- [ ] F. Release prep (README roadmap, version 0.3.0)
- [ ] G. Adversarial review + fixes + regression tests
- [ ] H. Tag v0.3.0 + Release DMG

## Could NOT visually verify (no local Xcode) — compiled by CI, behaviour not exercised
_Filled in as UI/drag/share code lands._

## Decisions / notes
- Mirrors Battery/Calendar. FS is available in CI, so DiskFileSource is tested for real.
- Staging dir = Application Support/gh-notch/Shelf (survives relaunch); injectable for tests.
- App is not sandboxed → no file entitlement needed.
- The expanded panel keeps growing per feature; a scroll/section restructure is future work.
