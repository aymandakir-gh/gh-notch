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
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString)-keep.txt")
        try Data(repeating: 0x42, count: 16).write(to: file)
        addTeardownBlock { try? FileManager.default.removeItem(at: file) }

        let store1 = ShelfStore(source: DiskFileSource(baseDirectory: base))
        _ = await store1.add(file)
        XCTAssertEqual(store1.items.count, 1)

        // New store on the same base == relaunch.
        let store2 = ShelfStore(source: DiskFileSource(baseDirectory: base))
        XCTAssertEqual(store2.items.count, 1)
        XCTAssertEqual(store2.items.first?.displayName, "keep.txt")
    }
}
