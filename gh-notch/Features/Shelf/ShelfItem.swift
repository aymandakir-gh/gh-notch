import Foundation

/// One file held on the shelf. A pure value type (no AppKit) and `Codable` so the
/// shelf index persists across launches. `id` doubles as the per-item staging
/// subdirectory name; `stagedName` is the copied file's name within it.
struct ShelfItem: Equatable, Identifiable, Codable {
    let id: String
    /// Absolute path of the dragged-in original — used for dedupe.
    let originalPath: String
    /// Filename of the staged copy inside the item's staging subdirectory.
    let stagedName: String
    /// Original filename, shown in the UI.
    let displayName: String
    let byteSize: Int64
    let isDirectory: Bool
    let addedAt: Date

    init(
        id: String,
        originalPath: String,
        stagedName: String,
        displayName: String,
        byteSize: Int64,
        isDirectory: Bool,
        addedAt: Date
    ) {
        self.id = id
        self.originalPath = originalPath
        self.stagedName = stagedName
        self.displayName = displayName
        self.byteSize = byteSize
        self.isDirectory = isDirectory
        self.addedAt = addedAt
    }
}
