import Foundation

/// Real `FileSource`: stages files into per-item UUID subdirectories under a base
/// directory (default `Application Support/gh-notch/Shelf`, so the shelf survives
/// relaunch) and persists a JSON index. The base directory is injectable so tests
/// run against a throwaway temp directory.
struct DiskFileSource: FileSource {
    let baseDirectory: URL
    private let fileManager: FileManager

    private var indexURL: URL {
        baseDirectory.appendingPathComponent("index.json")
    }

    init(baseDirectory: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        if let baseDirectory {
            self.baseDirectory = baseDirectory
        } else {
            let root = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? fileManager.temporaryDirectory
            self.baseDirectory = root.appendingPathComponent("gh-notch/Shelf", isDirectory: true)
        }
    }

    func stagedURL(for item: ShelfItem) -> URL {
        baseDirectory
            .appendingPathComponent(item.id, isDirectory: true)
            .appendingPathComponent(item.stagedName)
    }

    func stage(_ source: URL) async throws -> ShelfItem {
        try ensureBaseDirectory()
        let displayName = source.lastPathComponent
        let id = UUID().uuidString
        let itemDir = baseDirectory.appendingPathComponent(id, isDirectory: true)
        try fileManager.createDirectory(at: itemDir, withIntermediateDirectories: true)
        let destination = itemDir.appendingPathComponent(displayName)
        try fileManager.copyItem(at: source, to: destination)

        let values = try? source.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
        let size = values?.fileSize.flatMap { Int64($0) } ?? 0
        let isDirectory = values?.isDirectory ?? false

        return ShelfItem(
            id: id, originalPath: source.path, stagedName: displayName,
            displayName: displayName, byteSize: size, isDirectory: isDirectory, addedAt: Date()
        )
    }

    func remove(_ item: ShelfItem) throws {
        let itemDir = baseDirectory.appendingPathComponent(item.id, isDirectory: true)
        if fileManager.fileExists(atPath: itemDir.path) {
            try fileManager.removeItem(at: itemDir)
        }
    }

    func clear() throws {
        if fileManager.fileExists(atPath: baseDirectory.path) {
            try fileManager.removeItem(at: baseDirectory)
        }
    }

    func persist(_ items: [ShelfItem]) throws {
        try ensureBaseDirectory()
        let data = try JSONEncoder().encode(items)
        try data.write(to: indexURL, options: .atomic)
    }

    func load() -> [ShelfItem] {
        let stored = readIndex()
        // Drop entries whose staged copy has vanished (e.g. deleted out from under us).
        let kept = stored.filter { fileManager.fileExists(atPath: stagedURL(for: $0).path) }
        let removedOrphans = deleteOrphanDirectories(keeping: kept)
        // Converge the on-disk index: rewrite it if we pruned entries or removed
        // orphaned staged directories (left by a failed persist / eviction).
        if kept.count != stored.count || removedOrphans {
            try? persist(kept)
        }
        return kept
    }

    private func readIndex() -> [ShelfItem] {
        guard
            let data = try? Data(contentsOf: indexURL),
            let items = try? JSONDecoder().decode([ShelfItem].self, from: data)
        else {
            return []
        }
        return items
    }

    /// Delete staged subdirectories with no matching index entry. Returns whether
    /// anything was removed. (index.json is a file, so it is skipped.)
    private func deleteOrphanDirectories(keeping items: [ShelfItem]) -> Bool {
        let keptIDs = Set(items.map(\.id))
        guard let entries = try? fileManager.contentsOfDirectory(
            at: baseDirectory, includingPropertiesForKeys: [.isDirectoryKey]
        ) else {
            return false
        }
        var removed = false
        for entry in entries {
            let isDirectory = (try? entry.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            guard isDirectory, !keptIDs.contains(entry.lastPathComponent) else { continue }
            try? fileManager.removeItem(at: entry)
            removed = true
        }
        return removed
    }

    private func ensureBaseDirectory() throws {
        if !fileManager.fileExists(atPath: baseDirectory.path) {
            try fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        }
    }
}
