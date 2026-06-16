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
- [x] G. Adversarial review (32 agents, 5 dimensions) + fixes + regression tests — 21 confirmed findings
- [x] H. Tagged v0.3.0 — Release workflow built + published gh-notch.dmg

## Result
v0.3.0 shipped: https://github.com/aymandakir-gh/gh-notch/releases/tag/v0.3.0 (gh-notch.dmg).
43 shelf tests (logic/metadata/persistence/store); every slice CI-green before its tag.

## Review fixes applied (slice G)
- high: ShelfStore.add reentrancy — in-flight-path Set + post-await re-check so concurrent drops of
  the same file stage/insert once; generation token so a clear() during staging discards the result.
- high: dragging a chip out now pins the panel open (ShelfStore.isDraggingOut → pinnedOpen) so it
  doesn't auto-collapse mid-drag.
- med: humanSize unit rollover (999_999 B → "1 MB", not "1000 KB").
- med: clear() writes an authoritative empty index (try? persist([])) so a cleared shelf can't resurrect.
- med: load() reconciles — prunes vanished entries AND deletes orphaned staged dirs, rewriting the index.
- low: dedupe normalizes paths (resolvingSymlinksInPath/standardized); folders show "Folder" not "0 B";
  drag-out guards a missing staged file; share button gets imageScaling + a bigger hit target.
- config: force_unwrapping pinned to `error` in .swiftlint.yml (was opt-in/warning).
- +9 regression tests (concurrent dedupe, symlink dedupe, humanSize rollover, svg/docx category,
  clear-empty-index, orphan reconcile, pruned-index rewrite). Shelf tests now 43.
- DEFERRED (documented): non-Sendable FileSource existential (Swift-6 readiness, same as Calendar);
  the fixed 410pt panel height (future scroll/section-collapse restructure); per-drop failure feedback.

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
