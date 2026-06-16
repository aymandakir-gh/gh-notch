import Foundation

/// Pure list transforms for the shelf: newest-first insertion with a max-N cap,
/// move-to-front (for re-adds), and removal. No filesystem — the store handles
/// staging; this just decides the resulting order and what got evicted.
enum ShelfLogic {

    /// Insert `item` at the front (newest first), drop any existing entry with the
    /// same id, and enforce `maxItems`. Returns the new list and any evicted items
    /// (so the caller can delete their staged copies). `maxItems <= 0` means no cap.
    /// (The store dedupes by `originalPath` before calling this; the id-dedupe here
    /// is defensive — pure list logic shouldn't assume the caller pre-deduped.)
    static func inserting(
        _ item: ShelfItem,
        into items: [ShelfItem],
        maxItems: Int
    ) -> (items: [ShelfItem], evicted: [ShelfItem]) {
        var result = [item] + items.filter { $0.id != item.id }
        guard maxItems > 0, result.count > maxItems else { return (result, []) }
        let evicted = Array(result[maxItems...])
        result = Array(result[..<maxItems])
        return (result, evicted)
    }

    /// Move the item with `id` to the front, preserving the rest. No-op if absent.
    static func moveToFront(_ id: String, in items: [ShelfItem]) -> [ShelfItem] {
        guard let item = items.first(where: { $0.id == id }) else { return items }
        return [item] + items.filter { $0.id != id }
    }

    /// Remove the item with `id`.
    static func removing(_ id: String, from items: [ShelfItem]) -> [ShelfItem] {
        items.filter { $0.id != id }
    }
}
