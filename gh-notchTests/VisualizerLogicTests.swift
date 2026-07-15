import XCTest
@testable import gh_notch

final class VisualizerLogicTests: XCTestCase {

    private typealias Viz = VisualizerLogic

    // MARK: bucket

    func testBucketAveragesContiguousBins() {
        XCTAssertEqual(Viz.bucket(magnitudes: [1, 2, 3, 4], bars: 2), [1.5, 3.5])
    }

    func testBucketEvenSplitOfEight() {
        XCTAssertEqual(Viz.bucket(magnitudes: [0, 0, 4, 4, 8, 8, 12, 12], bars: 4),
                       [0, 4, 8, 12])
    }

    func testBucketMoreBarsThanBinsFallsBackToNearest() {
        XCTAssertEqual(Viz.bucket(magnitudes: [1, 2], bars: 4), [1, 1, 2, 2])
    }

    func testBucketEmptySpectrumIsZeros() {
        XCTAssertEqual(Viz.bucket(magnitudes: [], bars: 3), [0, 0, 0])
    }

    func testBucketNonPositiveBarsIsEmpty() {
        XCTAssertEqual(Viz.bucket(magnitudes: [1, 2, 3], bars: 0), [])
    }

    // MARK: smoothed

    func testSmoothedRisesByAttack() {
        XCTAssertEqual(Viz.smoothed(previous: [0, 0], target: [1, 1], attack: 0.5, release: 0.1),
                       [0.5, 0.5])
    }

    func testSmoothedFallsByRelease() {
        let out = Viz.smoothed(previous: [1, 1], target: [0, 0], attack: 0.5, release: 0.1)
        XCTAssertEqual(out[0], 0.9, accuracy: 1e-9)
        XCTAssertEqual(out[1], 0.9, accuracy: 1e-9)
    }

    func testSmoothedClampsCoefficients() {
        // attack > 1 clamps to 1 → jumps straight to target.
        XCTAssertEqual(Viz.smoothed(previous: [0], target: [1], attack: 5, release: 0.1), [1])
    }

    func testSmoothedLengthMismatchReturnsTarget() {
        XCTAssertEqual(Viz.smoothed(previous: [0], target: [1, 2], attack: 0.5, release: 0.5),
                       [1, 2])
    }

    // MARK: normalized

    func testNormalizedScalesByReference() {
        XCTAssertEqual(Viz.normalized([2, 4], reference: 4), [0.5, 1.0])
    }

    func testNormalizedClampsAboveReference() {
        XCTAssertEqual(Viz.normalized([8], reference: 4), [1.0])
    }

    func testNormalizedZeroReferenceIsSilent() {
        XCTAssertEqual(Viz.normalized([3, 9], reference: 0), [0, 0])
    }
}
