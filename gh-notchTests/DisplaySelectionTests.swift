import XCTest
@testable import gh_notch

final class DisplaySelectionTests: XCTestCase {

    private let builtIn = ScreenDescriptor(isBuiltIn: true, hasNotch: true, isMenuBarPrimary: true)
    private let external = ScreenDescriptor(isBuiltIn: false, hasNotch: false, isMenuBarPrimary: false)
    private let externalPrimary = ScreenDescriptor(isBuiltIn: false, hasNotch: false, isMenuBarPrimary: true)

    func testAllModeTargetsEveryScreen() {
        XCTAssertEqual(
            DisplaySelection.targetIndices(of: [builtIn, external, external], mode: .all),
            [0, 1, 2]
        )
    }

    func testBuiltInOnlyPicksTheBuiltInScreenWhereverItIs() {
        XCTAssertEqual(
            DisplaySelection.targetIndices(of: [external, builtIn], mode: .builtInOnly),
            [1]
        )
    }

    func testClamshellFallsBackToTheMenuBarScreen() {
        XCTAssertEqual(
            DisplaySelection.targetIndices(of: [external, externalPrimary], mode: .builtInOnly),
            [1]
        )
    }

    func testLastResortIsTheFirstScreen() {
        XCTAssertEqual(
            DisplaySelection.targetIndices(of: [external, external], mode: .builtInOnly),
            [0]
        )
    }

    func testNoScreensMeansNoPanels() {
        XCTAssertEqual(DisplaySelection.targetIndices(of: [], mode: .all), [])
        XCTAssertEqual(DisplaySelection.targetIndices(of: [], mode: .builtInOnly), [])
    }
}
