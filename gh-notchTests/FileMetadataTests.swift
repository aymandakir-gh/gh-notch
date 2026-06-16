import XCTest
@testable import gh_notch

final class FileMetadataTests: XCTestCase {

    // MARK: - Human size

    func testHumanSizeBytes() {
        XCTAssertEqual(FileMetadata.humanSize(0), "0 B")
        XCTAssertEqual(FileMetadata.humanSize(512), "512 B")
        XCTAssertEqual(FileMetadata.humanSize(999), "999 B")
    }

    func testHumanSizeKilobytes() {
        XCTAssertEqual(FileMetadata.humanSize(1000), "1 KB")
        XCTAssertEqual(FileMetadata.humanSize(1500), "1.5 KB")
    }

    func testHumanSizeMegabytes() {
        XCTAssertEqual(FileMetadata.humanSize(1_000_000), "1 MB")
        XCTAssertEqual(FileMetadata.humanSize(1_500_000), "1.5 MB")
    }

    func testHumanSizeGigabytes() {
        XCTAssertEqual(FileMetadata.humanSize(1_234_567_890), "1.2 GB")
    }

    func testHumanSizeRollsOverAtUnitBoundary() {
        // Just under a 1000-multiple must promote to the next unit, not show "1000 KB".
        XCTAssertEqual(FileMetadata.humanSize(999_999), "1 MB")
        XCTAssertEqual(FileMetadata.humanSize(999_999_999), "1 GB")
        XCTAssertEqual(FileMetadata.humanSize(999_999_999_999), "1 TB")
    }

    // MARK: - Category (fixture extensions)

    func testImageCategory() {
        XCTAssertEqual(FileMetadata.category(forExtension: "png"), .image)
        XCTAssertEqual(FileMetadata.category(forExtension: "jpg"), .image)
    }

    func testPDFCategory() {
        XCTAssertEqual(FileMetadata.category(forExtension: "pdf"), .pdf)
    }

    func testTextCategory() {
        XCTAssertEqual(FileMetadata.category(forExtension: "txt"), .text)
        XCTAssertEqual(FileMetadata.category(forExtension: "md"), .text)
    }

    func testAudioVideoArchiveCategory() {
        XCTAssertEqual(FileMetadata.category(forExtension: "mp3"), .audio)
        XCTAssertEqual(FileMetadata.category(forExtension: "mp4"), .video)
        XCTAssertEqual(FileMetadata.category(forExtension: "mov"), .video)
        XCTAssertEqual(FileMetadata.category(forExtension: "zip"), .archive)
    }

    func testUnknownAndEmptyCategory() {
        XCTAssertEqual(FileMetadata.category(forExtension: "xyz123"), .other)
        XCTAssertEqual(FileMetadata.category(forExtension: ""), .other)
    }

    func testConformanceOrderingForMultiTypeExtensions() {
        // svg conforms to BOTH image and text — image is checked first, so it wins.
        // Pin this so a future reorder of the conforms() checks can't silently regress it.
        XCTAssertEqual(FileMetadata.category(forExtension: "svg"), .image)
        XCTAssertEqual(FileMetadata.category(forExtension: "docx"), .other)
    }

    func testDirectoryWinsOverExtension() {
        XCTAssertEqual(FileMetadata.category(isDirectory: true, fileExtension: "png"), .folder)
        XCTAssertEqual(FileMetadata.category(isDirectory: false, fileExtension: "png"), .image)
    }

    func testCategorySymbolsAndLabels() {
        XCTAssertEqual(FileCategory.image.symbolName, "photo")
        XCTAssertEqual(FileCategory.folder.symbolName, "folder")
        XCTAssertEqual(FileCategory.other.symbolName, "doc")
        XCTAssertEqual(FileCategory.pdf.label, "PDF")
        XCTAssertEqual(FileCategory.folder.label, "Folder")
    }
}
