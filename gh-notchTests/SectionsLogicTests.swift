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

    func testDisplayAndBehaviorKeysDefaultAndPersist() {
        let suite = "test.appsettings.\(UUID().uuidString)"
        let (store, defaults) = makeStore(suite: suite)

        XCTAssertEqual(store.showOnDisplays, .builtInOnly)
        XCTAssertEqual(store.hoverDwell, NotchMotion.defaultHoverDwell, accuracy: 0.001)
        XCTAssertNil(store.notchWidthOverride)

        store.showOnDisplays = .all
        store.hoverDwell = 0.25
        store.notchWidthOverride = 240

        let reloaded = AppSettingsStore(defaults: defaults)
        XCTAssertEqual(reloaded.showOnDisplays, .all)
        XCTAssertEqual(reloaded.hoverDwell, 0.25, accuracy: 0.001)
        XCTAssertEqual(reloaded.notchWidthOverride, 240)
        defaults.removePersistentDomain(forName: suite)
    }

    func testClearingWidthOverrideRemovesTheKey() {
        let suite = "test.appsettings.\(UUID().uuidString)"
        let (store, defaults) = makeStore(suite: suite)

        store.notchWidthOverride = 300
        store.notchWidthOverride = nil
        let reloaded = AppSettingsStore(defaults: defaults)
        XCTAssertNil(reloaded.notchWidthOverride)
        defaults.removePersistentDomain(forName: suite)
    }

    func testHoverDwellIsClampedOnLoad() {
        let suite = "test.appsettings.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        defaults.removePersistentDomain(forName: suite)
        defaults.set(9.0, forKey: "display.hoverDwell") // absurd persisted value

        let store = AppSettingsStore(defaults: defaults)
        XCTAssertEqual(store.hoverDwell, 0.5, accuracy: 0.001)
        defaults.removePersistentDomain(forName: suite)
    }

    func testHoverDwellIsClampedOnSet() {
        let suite = "test.appsettings.\(UUID().uuidString)"
        let (store, defaults) = makeStore(suite: suite)

        store.hoverDwell = 9.0    // above the 0.5 ceiling
        XCTAssertEqual(store.hoverDwell, 0.5, accuracy: 0.001)

        store.hoverDwell = -1.0   // below the 0 floor
        XCTAssertEqual(store.hoverDwell, 0.0, accuracy: 0.001)

        // the clamped value (not the raw input) is what persists across a reload
        let reloaded = AppSettingsStore(defaults: defaults)
        XCTAssertEqual(reloaded.hoverDwell, 0.0, accuracy: 0.001)
        defaults.removePersistentDomain(forName: suite)
    }
}
