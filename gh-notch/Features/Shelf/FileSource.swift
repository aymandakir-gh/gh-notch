import Foundation

/// Staging + persistence backend for the shelf, abstracted behind a protocol so
/// `ShelfStore` is testable with a fake. `stage` is `async` so the real file copy
/// runs off the main actor. `DiskFileSource` is the real implementation;
/// `FakeFileSource` is the in-memory one used by tests and previews.
protocol FileSource {
    /// Copy `source` into staging and return the resulting item.
    func stage(_ source: URL) async throws -> ShelfItem
    /// Delete a staged item's files.
    func remove(_ item: ShelfItem) throws
    /// Delete all staged files + the index.
    func clear() throws
    /// Persist the current shelf index.
    func persist(_ items: [ShelfItem]) throws
    /// Load the persisted index (pruning entries whose staged file is gone).
    func load() -> [ShelfItem]
    /// On-disk location of a staged item (for drag-out / share).
    func stagedURL(for item: ShelfItem) -> URL
}

/// In-memory `FileSource` for unit tests and SwiftUI previews.
final class FakeFileSource: FileSource {
    private(set) var stored: [ShelfItem]
    private(set) var stageCallCount = 0
    /// When true, `stage` throws — to test the failure path.
    var failStaging = false

    init(initial: [ShelfItem] = []) {
        self.stored = initial
    }

    func stage(_ source: URL) async throws -> ShelfItem {
        stageCallCount += 1
        if failStaging { throw CocoaError(.fileReadNoSuchFile) }
        let name = source.lastPathComponent
        return ShelfItem(
            id: UUID().uuidString, originalPath: source.path, stagedName: name,
            displayName: name, byteSize: 0, isDirectory: false, addedAt: Date()
        )
    }

    func remove(_ item: ShelfItem) throws { stored.removeAll { $0.id == item.id } }
    func clear() throws { stored.removeAll() }
    func persist(_ items: [ShelfItem]) throws { stored = items }
    func load() -> [ShelfItem] { stored }
    func stagedURL(for item: ShelfItem) -> URL {
        URL(fileURLWithPath: "/fake/\(item.id)/\(item.stagedName)")
    }
}
