import XCTest
@testable import gh_notch

final class ShelfLogicTests: XCTestCase {

    private func item(_ id: String) -> ShelfItem {
        ShelfItem(id: id, originalPath: "/orig/\(id)", stagedName: "\(id).txt",
                  displayName: "\(id).txt", byteSize: 1, isDirectory: false,
                  addedAt: Date(timeIntervalSinceReferenceDate: 0))
    }

    func testInsertIntoEmpty() {
        let result = ShelfLogic.inserting(item("a"), into: [], maxItems: 10)
        XCTAssertEqual(result.items.map(\.id), ["a"])
        XCTAssertTrue(result.evicted.isEmpty)
    }

    func testInsertIsNewestFirst() {
        let result = ShelfLogic.inserting(item("b"), into: [item("a")], maxItems: 10)
        XCTAssertEqual(result.items.map(\.id), ["b", "a"])
    }

    func testInsertDedupesById() {
        let result = ShelfLogic.inserting(item("a"), into: [item("a"), item("b")], maxItems: 10)
        XCTAssertEqual(result.items.map(\.id), ["a", "b"])
        XCTAssertTrue(result.evicted.isEmpty)
    }

    func testCapEvictsOldest() {
        let result = ShelfLogic.inserting(item("c"), into: [item("b"), item("a")], maxItems: 2)
        XCTAssertEqual(result.items.map(\.id), ["c", "b"])
        XCTAssertEqual(result.evicted.map(\.id), ["a"])
    }

    func testInsertWhenFullKeepsCap() {
        let result = ShelfLogic.inserting(item("d"), into: [item("c"), item("b"), item("a")], maxItems: 3)
        XCTAssertEqual(result.items.map(\.id), ["d", "c", "b"])
        XCTAssertEqual(result.evicted.map(\.id), ["a"])
    }

    func testZeroOrNegativeMaxMeansNoCap() {
        let result = ShelfLogic.inserting(item("c"), into: [item("b"), item("a")], maxItems: 0)
        XCTAssertEqual(result.items.count, 3)
        XCTAssertTrue(result.evicted.isEmpty)
    }

    func testMoveToFront() {
        let moved = ShelfLogic.moveToFront("a", in: [item("b"), item("a"), item("c")])
        XCTAssertEqual(moved.map(\.id), ["a", "b", "c"])
    }

    func testMoveToFrontAbsentIsNoop() {
        let moved = ShelfLogic.moveToFront("z", in: [item("b"), item("a")])
        XCTAssertEqual(moved.map(\.id), ["b", "a"])
    }

    func testRemoving() {
        let after = ShelfLogic.removing("a", from: [item("b"), item("a"), item("c")])
        XCTAssertEqual(after.map(\.id), ["b", "c"])
    }
}
