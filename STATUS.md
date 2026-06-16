# STATUS — v0.3.0 File Shelf

Living progress log. See PLAN.md for the design. (v0.1.x polish and v0.2.0 Calendar
already shipped — see git history / CLAUDE.md.)

## Slices
- [x] A. Pure core (ShelfItem, ShelfLogic, FileMetadata) + tests — CI green (19 tests)
- [x] B. Service + store (FileSource, DiskFileSource, FakeFileSource, ShelfStore) + tests — CI green (35 shelf tests total)
- [x] C. ShelfView (chips + remove + clear-all + empty state) mounted in the expanded panel — CI green
- [x] D. Drag-IN (.onDrop [.fileURL] → loadObject(URL) → store.add) — CI green
- [x] E. Drag-OUT (.onDrag NSItemProvider) + NSSharingServicePicker share (AirDrop) — CI green
- [x] F. Release prep (README roadmap File Shelf ✅, version → 0.3.0) — this commit
- [ ] G. Adversarial review + fixes + regression tests
- [ ] H. Tag v0.3.0 + Release DMG

## Could NOT visually verify (no local Xcode) — compiled by CI, behaviour not exercised
- Drag-IN: the SwiftUI `.onDrop(of: [.fileURL])` decoding + `NSItemProvider.loadObject(ofClass: URL.self)`
  actually receiving Finder file drops, and the "Release to add" targeted highlight. (`ShelfStore.add`
  the drop calls is unit-tested.)
- Drag-OUT: `.onDrag { NSItemProvider(contentsOf: stagedURL) }` actually copying the staged file to
  Finder/another app. (`stagedURL` is unit-tested.)
- Share/AirDrop: the `SharePickerButton` NSViewRepresentable presenting `NSSharingServicePicker`
  anchored to its NSButton, and AirDrop appearing in the picker.
- Layout: the Shelf section's chips/empty-state rendering, and the expanded panel at 410pt not
  clipping (sized for the worst case, so otherwise it shows whitespace).
- The real Application-Support staging dir on a live machine (tests inject a temp base dir).

## Decisions / notes
- Mirrors Battery/Calendar. FS is available in CI, so DiskFileSource is tested for real.
- Staging dir = Application Support/gh-notch/Shelf (survives relaunch); injectable for tests.
- App is not sandboxed → no file entitlement needed.
- The expanded panel keeps growing per feature; a scroll/section restructure is future work.
