import XCTest
@testable import gh_notch

final class SectionsLogicTests: XCTestCase {

    func testAllSectionsVisibleByDefaultInRegistryOrder() {
        XCTAssertEqual(
            SectionsLogic.visibleSections(disabled: []),
            [.commandBar, .calendar, .shelf, .statusRow]
        )
    }

    func testDisabledSectionsAreFilteredOutKeepingOrder() {
        XCTAssertEqual(
            SectionsLogic.visibleSections(disabled: [.calendar]),
            [.commandBar, .shelf, .statusRow]
        )
        XCTAssertEqual(
            SectionsLogic.visibleSections(disabled: [.commandBar, .shelf]),
            [.calendar, .statusRow]
        )
    }

    func testStatusRowCanNeverBeDisabled() {
        // The gear in the status row is the only discoverable path to Settings.
        let all = Set(ExpandedSection.allCases)
        XCTAssertEqual(SectionsLogic.visibleSections(disabled: all), [.statusRow])
    }

    func testRawValueRoundTripIsStableAndSorted() {
        let disabled: Set<ExpandedSection> = [.shelf, .commandBar]
        let raw = SectionsLogic.rawValues(from: disabled)
        XCTAssertEqual(raw, ["commandBar", "shelf"]) // sorted for stable writes
        XCTAssertEqual(SectionsLogic.disabledSet(fromRawValues: raw), disabled)
    }

    func testUnknownPersistedValuesAreDroppedNotFatal() {
        let set = SectionsLogic.disabledSet(fromRawValues: ["calendar", "vanishedFeature", ""])
        XCTAssertEqual(set, [.calendar])
    }
}

@MainActor
final class AppSettingsStoreTests: XCTestCase {

    private func makeStore(suite: String) -> (AppSettingsStore, UserDefaults) {
        // Force-unwrap-free: suiteName only fails for the global domain.
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        defaults.removePersistentDomain(forName: suite)
        return (AppSettingsStore(defaults: defaults), defaults)
    }

    func testTogglePersistsAcrossReload() {
        let suite = "test.appsettings.\(UUID().uuidString)"
        let (store, defaults) = makeStore(suite: suite)

        store.setSection(.calendar, enabled: false)
        XCTAssertEqual(store.visibleSections, [.commandBar, .shelf, .statusRow])

        let reloaded = AppSettingsStore(defaults: defaults)
        XCTAssertEqual(reloaded.disabledSections, [.calendar])
        defaults.removePersistentDomain(forName: suite)
    }

    func testAlwaysOnSectionIgnoresDisableRequests() {
        let suite = "test.appsettings.\(UUID().uuidString)"
        let (store, defaults) = makeStore(suite: suite)

        store.setSection(.statusRow, enabled: false)
        XCTAssertFalse(store.disabledSections.contains(.statusRow))
        XCTAssertTrue(store.visibleSections.contains(.statusRow))
        defaults.removePersistentDomain(forName: suite)
    }

    func testBlendCollapsedDefaultsOnAndPersists() {
        let suite = "test.appsettings.\(UUID().uuidString)"
        let (store, defaults) = makeStore(suite: suite)

        XCTAssertTrue(store.blendCollapsed) // v0.3 look preserved by default
        store.blendCollapsed = false
        let reloaded = AppSettingsStore(defaults: defaults)
        XCTAssertFalse(reloaded.blendCollapsed)
        defaults.removePersistentDomain(forName: suite)
    }

    func testReEnablingRemovesFromDisabledSet() {
        let suite = "test.appsettings.\(UUID().uuidString)"
        let (store, defaults) = makeStore(suite: suite)

        store.setSection(.shelf, enabled: false)
        store.setSection(.shelf, enabled: true)
        XCTAssertEqual(store.disabledSections, [])
        defaults.removePersistentDomain(forName: suite)
    }
}
