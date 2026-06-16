import XCTest
@testable import gh_notch

final class DiskFileSourceTests: XCTestCase {

    private func tempBase() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("shelf-\(UUID().uuidString)", isDirectory: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        return dir
    }

    private func tempFile(_ name: String, bytes: Int) throws -> URL {
        // Put the file in a unique subdirectory so its own name stays clean
        // (the staged displayName is the source's lastPathComponent).
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("src-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent(name)
        try Data(repeating: 0x41, count: bytes).write(to: url)
        return url
    }

    func testStageCopiesFileAndReadsSize() async throws {
        let source = DiskFileSource(baseDirectory: tempBase())
        let item = try await source.stage(try tempFile("report.pdf", bytes: 2048))
        XCTAssertEqual(item.displayName, "report.pdf")
        XCTAssertEqual(item.byteSize, 2048)
        XCTAssertFalse(item.isDirectory)
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.stagedURL(for: item).path))
    }

    func testStageMissingFileThrows() async {
        let source = DiskFileSource(baseDirectory: tempBase())
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("absent-\(UUID().uuidString).txt")
        do {
            _ = try await source.stage(missing)
            XCTFail("expected stage to throw for a missing file")
        } catch {
            // expected
        }
    }

    func testRemoveDeletesStagedItem() async throws {
        let source = DiskFileSource(baseDirectory: tempBase())
        let item = try await source.stage(try tempFile("a.txt", bytes: 10))
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.stagedURL(for: item).path))
        try source.remove(item)
        XCTAssertFalse(FileManager.default.fileExists(atPath: source.stagedURL(for: item).path))
    }

    func testClearEmptiesEverything() async throws {
        let base = tempBase()
        let source = DiskFileSource(baseDirectory: base)
        _ = try await source.stage(try tempFile("a.txt", bytes: 10))
        try source.persist([])
        try source.clear()
        XCTAssertFalse(FileManager.default.fileExists(atPath: base.path))
        XCTAssertTrue(source.load().isEmpty)
    }

    func testPersistAndLoadRoundTrip() async throws {
        let source = DiskFileSource(baseDirectory: tempBase())
        let item = try await source.stage(try tempFile("a.txt", bytes: 64))
        try source.persist([item])
        let loaded = source.load()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.id, item.id)
        XCTAssertEqual(loaded.first?.displayName, item.displayName)
        XCTAssertEqual(loaded.first?.byteSize, item.byteSize)
        XCTAssertEqual(loaded.first?.originalPath, item.originalPath)
        XCTAssertEqual(loaded.first?.addedAt.timeIntervalSinceReferenceDate ?? 0,
                       item.addedAt.timeIntervalSinceReferenceDate, accuracy: 0.001)
    }

    func testIndexSurvivesRelaunch() async throws {
        let base = tempBase()
        let writer = DiskFileSource(baseDirectory: base)
        let item = try await writer.stage(try tempFile("keep.txt", bytes: 5))
        try writer.persist([item])
        // A fresh instance reading the same base == a relaunch.
        let reader = DiskFileSource(baseDirectory: base)
        XCTAssertEqual(reader.load().map(\.id), [item.id])
    }

    func testLoadPrunesMissingStagedFile() async throws {
        let source = DiskFileSource(baseDirectory: tempBase())
        let item = try await source.stage(try tempFile("gone.txt", bytes: 5))
        try source.persist([item])
        try source.remove(item) // staged copy deleted, but index still references it
        XCTAssertTrue(source.load().isEmpty)
    }

    func testStagedURLShape() {
        let base = tempBase()
        let source = DiskFileSource(baseDirectory: base)
        let item = ShelfItem(id: "ID1", originalPath: "/x", stagedName: "f.txt",
                             displayName: "f.txt", byteSize: 1, isDirectory: false, addedAt: Date())
        let expected = base.appendingPathComponent("ID1").appendingPathComponent("f.txt")
        XCTAssertEqual(source.stagedURL(for: item), expected)
    }
}
