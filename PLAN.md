# PLAN — v0.3.0 File Shelf

Adds a File Shelf to gh-notch, mirroring the Battery/Calendar shape (value types +
protocol-backed source with an injectable fake + pure tested logic + @Observable
store + SwiftUI view). ONE feature this pass.

## Verification reality
No local Xcode. BUT the filesystem IS available in CI, so unlike EventKit/IOKit the
*real* `DiskFileSource` (staging + persistence) is unit-tested against real temp
files — only the AppKit drag-in/drag-out/share picker and the SwiftUI layout are
compiled-but-not-behaviour-verified (listed in STATUS.md).

## Architecture (mirrors Features/Calendar)
- `ShelfItem` — pure value type, `Equatable, Identifiable, Codable`:
  `id` (UUID, also the per-item staging subdir), `originalPath` (for dedupe),
  `stagedName` (filename inside the subdir), `displayName`, `byteSize`, `isDirectory`,
  `addedAt`. No AppKit/EventKit.
- `ShelfLogic` — pure list transforms: `inserting(_:into:maxItems:)` → (newest-first
  list, evicted) with the max-N cap; `moveToFront`; `removing`. No FS.
- `FileMetadata` — pure: `humanSize(Int64)` (decimal, en_US_POSIX so it's locale-stable
  like the command bar), `category(forExtension:)`/`category(for:)` → `FileCategory`
  {image,pdf,text,audio,video,archive,folder,other} via UTType, and each category's
  SF-symbol + label. (Type/icon "resolution tested against fixtures".)
- `FileSource` — protocol (injectable source):
  `stage(_:) async throws -> ShelfItem` (async so the copy runs off-main),
  `remove`, `clear`, `persist([ShelfItem])`, `load() -> [ShelfItem]`, `stagedURL(for:)`.
  - `DiskFileSource` — real: a base dir (default Application Support/gh-notch/Shelf, so it
    survives relaunch; INJECTABLE so tests use a unique temp dir), per-item UUID subdir
    holding the original-named copy (collision-free, drag-out keeps the real name), and a
    JSON `index.json`. `load()` prunes entries whose staged file vanished.
  - `FakeFileSource` — in-memory, records `stage` calls; powers store tests + previews.
- `ShelfStore` — `@Observable @MainActor`: `items`, `add(_:) async`, `remove`, `clear`,
  `stagedURL(for:)`. add() dedupes by `originalPath` (move-to-front, no restage), else
  stages + applies ShelfLogic (cap + evict, deleting evicted staged files) + persists.
  `init` loads the persisted index.

## UI (isolated, in the expanded panel, between Calendar agenda and status row)
- `ShelfView`: a "Shelf" header with a clear-all (trash) button + a horizontal scroll of
  item chips (SF-symbol-by-category + truncated name + per-item remove ✕). Empty state:
  a dashed "Drop files here" target. Consistent with Battery/Calendar styling.
- Drag-IN: `.dropDestination(for: URL.self)` on the shelf area (and the whole expanded
  surface) → `Task { for url in urls { await shelf.add(url) } }`, with a targeted highlight.
- Drag-OUT: each chip `.onDrag { NSItemProvider(contentsOf: stagedURL) ?? NSItemProvider() }`
  → drop onto Finder/another app copies the staged file.
- Share/AirDrop: a per-chip share button via a tiny `SharePicker` NSViewRepresentable that
  anchors `NSSharingServicePicker(items: [stagedURL]).show(relativeTo:of:preferredEdge:)`.
- `expandedSize.height` grows to fit the new section (kept fixed; sparse states show
  whitespace — a scroll/section-collapse restructure is noted as future, out of scope).

## Wiring
- No new entitlement (app is NOT sandboxed, so dropped-file access needs none; if it were
  sandboxed it would need `com.apple.security.files.user-selected.read-write`).
- `MARKETING_VERSION` 0.2.0 → 0.3.0; verify Info.plist idempotent + version not clobbered.
- README roadmap: File Shelf ✅.

## Slices (each: parse-check → xcodegen → commit → push → CI green)
- A. Pure core: ShelfItem, ShelfLogic, FileMetadata + tests (~15).
- B. Service + store: FileSource, DiskFileSource (real temp-file tests), FakeFileSource,
     ShelfStore + tests incl. persistence-across-relaunch (~18+). Total ≥ 30.
- C. ShelfView (rows + remove + clear-all + empty state) mounted in NotchView.
- D. Drag-IN.
- E. Drag-OUT + NSSharingServicePicker share.
- F. Release prep: README, version 0.3.0, STATUS.
- G. Adversarial review → fix every real finding + regression tests.
- H. Tag v0.3.0 → Release DMG.

## Test coverage targets (CI-run)
ShelfLogic: insert newest-first, cap eviction (oldest dropped + reported), dup-id replace,
move-to-front, remove, empty/boundary. FileMetadata: humanSize (0/B/KB/MB/GB rounding,
locale-stable '.'), category for png/pdf/txt/mp3/mp4/zip/unknown/folder, symbol/label per
category. DiskFileSource: stage a real temp file (copy exists + size), stage missing →
throws, remove deletes subdir, clear empties, persist+load round-trip, load from a fresh
instance (relaunch), prune missing staged file, stagedURL shape. ShelfStore: add/remove/
clear, dedupe-by-path (no second stage call), cap enforcement, persistence across new store.
