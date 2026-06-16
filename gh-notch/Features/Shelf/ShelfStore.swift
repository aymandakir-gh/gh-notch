import Foundation
import Observation

/// Observable shelf state: the held items, plus add/remove/clear. Mirrors the
/// Battery/Calendar models — an injected `FileSource` does the staging/persistence,
/// `ShelfLogic` decides ordering/cap. `add` is `async` so the file copy runs off
/// the main actor; the index is reloaded at init so the shelf survives relaunch.
@Observable
@MainActor
final class ShelfStore {

    private(set) var items: [ShelfItem] = []

    @ObservationIgnored let maxItems: Int
    @ObservationIgnored private let source: FileSource

    init(source: FileSource = DiskFileSource(), maxItems: Int = 20) {
        self.source = source
        self.maxItems = maxItems
        self.items = source.load()
    }

    var isEmpty: Bool { items.isEmpty }

    /// Stage `url` onto the shelf. Re-adding the same original path moves the
    /// existing entry to the front instead of duplicating it. Returns false if
    /// staging failed (e.g. the file is gone).
    @discardableResult
    func add(_ url: URL) async -> Bool {
        if let existing = items.first(where: { $0.originalPath == url.path }) {
            items = ShelfLogic.moveToFront(existing.id, in: items)
            try? source.persist(items)
            return true
        }
        guard let staged = try? await source.stage(url) else { return false }
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
        items = []
        try? source.clear()
    }

    /// On-disk URL of a staged item — for drag-out and the share picker.
    func stagedURL(for item: ShelfItem) -> URL {
        source.stagedURL(for: item)
    }
}
