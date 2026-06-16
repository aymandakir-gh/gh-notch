import XCTest
@testable import gh_notch

@MainActor
final class ShelfStoreTests: XCTestCase {

    private func fileURL(_ name: String) -> URL { URL(fileURLWithPath: "/tmp/\(name)") }

    func testAddStagesAndAppends() async {
        let fake = FakeFileSource()
        let store = ShelfStore(source: fake, maxItems: 20)
        let added = await store.add(fileURL("a.txt"))
        XCTAssertTrue(added)
        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(fake.stageCallCount, 1)
    }

    func testAddDedupesByPathWithoutRestaging() async {
        let fake = FakeFileSource()
        let store = ShelfStore(source: fake)
        _ = await store.add(fileURL("a.txt"))
        _ = await store.add(fileURL("a.txt"))
        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(fake.stageCallCount, 1) // second add moved-to-front, no restage
    }

    func testAddEnforcesCap() async {
        let fake = FakeFileSource()
        let store = ShelfStore(source: fake, maxItems: 2)
        _ = await store.add(fileURL("a.txt"))
        _ = await store.add(fileURL("b.txt"))
        _ = await store.add(fileURL("c.txt"))
        XCTAssertEqual(store.items.count, 2)
        XCTAssertEqual(store.items.map(\.displayName), ["c.txt", "b.txt"])
    }

    func testRemove() async {
        let fake = FakeFileSource()
        let store = ShelfStore(source: fake)
        _ = await store.add(fileURL("a.txt"))
        guard let item = store.items.first else { return XCTFail("expected an item") }
        store.remove(item)
        XCTAssertTrue(store.isEmpty)
    }

    func testClear() async {
        let fake = FakeFileSource()
        let store = ShelfStore(source: fake)
        _ = await store.add(fileURL("a.txt"))
        _ = await store.add(fileURL("b.txt"))
        store.clear()
        XCTAssertTrue(store.isEmpty)
    }

    func testAddFailureReturnsFalse() async {
        let fake = FakeFileSource()
        fake.failStaging = true
        let store = ShelfStore(source: fake)
        let added = await store.add(fileURL("a.txt"))
        XCTAssertFalse(added)
        XCTAssertTrue(store.isEmpty)
    }

    func testInitLoadsPersistedItems() {
        let seed = ShelfItem(id: "x", originalPath: "/x", stagedName: "x.txt",
                             displayName: "x.txt", byteSize: 1, isDirectory: false, addedAt: Date())
        let store = ShelfStore(source: FakeFileSource(initial: [seed]))
        XCTAssertEqual(store.items.map(\.id), ["x"])
    }

    func testPersistenceAcrossRelaunchWithDisk() async throws {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("shelf-store-\(UUID().uuidString)", isDirectory: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: base) }
        // Source file in its own subdir so its name stays "keep.txt".
        let srcDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("src-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: srcDir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: srcDir) }
        let file = srcDir.appendingPathComponent("keep.txt")
        try Data(repeating: 0x42, count: 16).write(to: file)

        let store1 = ShelfStore(source: DiskFileSource(baseDirectory: base))
        _ = await store1.add(file)
        XCTAssertEqual(store1.items.count, 1)

        // New store on the same base == relaunch.
        let store2 = ShelfStore(source: DiskFileSource(baseDirectory: base))
        XCTAssertEqual(store2.items.count, 1)
        XCTAssertEqual(store2.items.first?.displayName, "keep.txt")
    }

    // MARK: - Regression: review findings

    func testConcurrentSamePathAddsStageOnce() async {
        // Two simultaneous drops of the same file must not race past the dedupe
        // check (which straddles the stage await) and stage/insert twice.
        let fake = FakeFileSource()
        let store = ShelfStore(source: fake)
        async let first = store.add(fileURL("dup.txt"))
        async let second = store.add(fileURL("dup.txt"))
        _ = await (first, second)
        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(fake.stageCallCount, 1)
    }

    func testDedupeResolvesSymlinks() async throws {
        // A file added via its real path and via a symlink to it dedupes to one entry.
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("shelf-symlink-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        let real = dir.appendingPathComponent("real.txt")
        try Data(repeating: 0x41, count: 8).write(to: real)
        let link = dir.appendingPathComponent("link.txt")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: real)

        let fake = FakeFileSource()
        let store = ShelfStore(source: fake)
        _ = await store.add(real)
        _ = await store.add(link)
        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(fake.stageCallCount, 1)
    }

    func testClearWritesEmptyIndexAuthoritatively() async throws {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("shelf-clear-\(UUID().uuidString)", isDirectory: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: base) }
        let srcDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("src-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: srcDir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: srcDir) }
        let file = srcDir.appendingPathComponent("a.txt")
        try Data(repeating: 0x41, count: 8).write(to: file)

        let store = ShelfStore(source: DiskFileSource(baseDirectory: base))
        _ = await store.add(file)
        store.clear()

        // An empty index.json must exist so a cleared shelf can't resurrect.
        let indexURL = base.appendingPathComponent("index.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: indexURL.path))
        let decoded = try JSONDecoder().decode([ShelfItem].self, from: Data(contentsOf: indexURL))
        XCTAssertTrue(decoded.isEmpty)

        let relaunched = ShelfStore(source: DiskFileSource(baseDirectory: base))
        XCTAssertTrue(relaunched.isEmpty)
    }
}
