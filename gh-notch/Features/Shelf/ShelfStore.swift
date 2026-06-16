import Foundation
import Observation

/// Observable shelf state: the held items, plus add/remove/clear. Mirrors the
/// Battery/Calendar models — an injected `FileSource` does the staging/persistence,
/// `ShelfLogic` decides ordering/cap. `add` is `async` so the file copy runs off
/// the main actor; the index is reconciled at init so the shelf survives relaunch.
@Observable
@MainActor
final class ShelfStore {

    private(set) var items: [ShelfItem] = []
    /// True while a shelf chip is being dragged out, so the panel can stay open.
    private(set) var isDraggingOut = false

    @ObservationIgnored let maxItems: Int
    @ObservationIgnored private let source: FileSource
    /// Original paths whose staging is in flight, so concurrent drops of the same
    /// file (the dedupe check straddles the `stage` await) don't stage it twice.
    @ObservationIgnored private var inFlightPaths: Set<String> = []
    /// Bumped by `clear()`; an add whose generation is stale discards its result so
    /// a clear during an in-flight stage can't leave a phantom entry.
    @ObservationIgnored private var generation = 0

    init(source: FileSource = DiskFileSource(), maxItems: Int = 20) {
        self.source = source
        self.maxItems = maxItems
        self.items = source.load()
    }

    var isEmpty: Bool { items.isEmpty }

    /// Stage `url` onto the shelf. Re-adding the same original path moves the
    /// existing entry to the front (it keeps the original staged copy — it does not
    /// re-snapshot a changed file). Returns false if staging failed or was
    /// superseded. Paths are normalized (symlinks/`..`/firmlinks) before comparing.
    @discardableResult
    func add(_ url: URL) async -> Bool {
        let normalized = url.resolvingSymlinksInPath().standardizedFileURL
        let path = normalized.path

        if let existing = items.first(where: { $0.originalPath == path }) {
            items = ShelfLogic.moveToFront(existing.id, in: items)
            try? source.persist(items)
            return true
        }
        // Guard against a concurrent drop of the same file: the dedupe check above
        // and the insert below straddle the `await`, so mark this path in flight
        // (synchronously, before suspending) and bail if it's already staging.
        guard !inFlightPaths.contains(path) else { return false }
        inFlightPaths.insert(path)
        defer { inFlightPaths.remove(path) }

        let dispatch = generation
        guard let staged = try? await source.stage(normalized) else { return false }

        // Superseded by a clear() while staging → drop the orphaned copy.
        guard dispatch == generation else {
            try? source.remove(staged)
            return true
        }
        // A concurrent add of the same path won the race → drop our duplicate copy.
        if items.contains(where: { $0.originalPath == staged.originalPath }) {
            try? source.remove(staged)
            return true
        }
        let result = ShelfLogic.inserting(staged, into: items, maxItems: maxItems)
        items = result.items
        for evicted in result.evicted {
            try? source.remove(evicted)
        }
        try? source.persist(items)
        return true
    }

    func remove(_ item: ShelfItem) {
        items = ShelfLogic.removing(item.id, from: items)
        try? source.remove(item)
        try? source.persist(items)
    }

    func clear() {
        generation &+= 1
        items = []
        try? source.clear()
        // Authoritative empty index even if the bulk delete partially failed, so a
        // cleared shelf can't resurrect on relaunch.
        try? source.persist([])
    }

    /// On-disk URL of a staged item — for drag-out and the share picker.
    func stagedURL(for item: ShelfItem) -> URL {
        source.stagedURL(for: item)
    }

    /// Pin the panel open for a moment while a chip is dragged out (SwiftUI's
    /// `.onDrag` has no end callback, so we clear the flag after a short window).
    func beginDragOut() {
        isDraggingOut = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.isDraggingOut = false
        }
    }
}
