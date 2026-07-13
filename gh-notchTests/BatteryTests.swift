import XCTest
import IOKit.ps
@testable import gh_notch

@MainActor
final class BatteryTests: XCTestCase {

    // MARK: - Snapshot mapping from IOKit dictionaries

    func testMapsDischargingSnapshot() {
        let description: [String: Any] = [
            kIOPSMaxCapacityKey: 100,
            kIOPSCurrentCapacityKey: 72,
            kIOPSIsChargingKey: false,
            kIOPSPowerSourceStateKey: kIOPSBatteryPowerValue,
            kIOPSTimeToEmptyKey: 85
        ]
        let snapshot = IOKitPowerSourceReader.snapshot(from: description)

        XCTAssertEqual(snapshot.percent, 72)
        XCTAssertFalse(snapshot.isCharging)
        XCTAssertFalse(snapshot.isPluggedIn)
        XCTAssertEqual(snapshot.minutesRemaining, 85)
        XCTAssertTrue(snapshot.hasBattery)
        XCTAssertEqual(snapshot.timeDescription, "1:25 left")
    }

    func testMapsChargingSnapshot() {
        let description: [String: Any] = [
            kIOPSMaxCapacityKey: 100,
            kIOPSCurrentCapacityKey: 40,
            kIOPSIsChargingKey: true,
            kIOPSPowerSourceStateKey: kIOPSACPowerValue,
            kIOPSTimeToFullChargeKey: 40
        ]
        let snapshot = IOKitPowerSourceReader.snapshot(from: description)

        XCTAssertEqual(snapshot.percent, 40)
        XCTAssertTrue(snapshot.isCharging)
        XCTAssertTrue(snapshot.isPluggedIn)
        XCTAssertEqual(snapshot.timeDescription, "0:40 to full")
    }

    func testNegativeTimeEstimateIsTreatedAsCalculating() {
        let description: [String: Any] = [
            kIOPSMaxCapacityKey: 100,
            kIOPSCurrentCapacityKey: 55,
            kIOPSIsChargingKey: false,
            kIOPSPowerSourceStateKey: kIOPSBatteryPowerValue,
            kIOPSTimeToEmptyKey: -1
        ]
        let snapshot = IOKitPowerSourceReader.snapshot(from: description)

        XCTAssertNil(snapshot.minutesRemaining)
        XCTAssertNil(snapshot.timeDescription)
    }

    func testPercentIsClampedAndDerivedFromCapacityRatio() {
        let description: [String: Any] = [
            kIOPSMaxCapacityKey: 80,
            kIOPSCurrentCapacityKey: 40, // 50%
            kIOPSIsChargingKey: false,
            kIOPSPowerSourceStateKey: kIOPSBatteryPowerValue
        ]
        let snapshot = IOKitPowerSourceReader.snapshot(from: description)
        XCTAssertEqual(snapshot.percent, 50)
    }

    func testNoBatterySnapshotHasNoTimeDescription() {
        XCTAssertFalse(BatterySnapshot.noBattery.hasBattery)
        XCTAssertNil(BatterySnapshot.noBattery.timeDescription)
    }

    // MARK: - Monitor with injected reader

    func testMonitorReadsFromInjectedReaderOnInit() {
        let stub = StubReader(snapshot: makeSnapshot(percent: 33))
        let monitor = BatteryMonitor(reader: stub, interval: 999)
        XCTAssertEqual(monitor.snapshot.percent, 33)
    }

    func testMonitorRefreshPullsLatestReading() {
        let stub = StubReader(snapshot: makeSnapshot(percent: 33))
        let monitor = BatteryMonitor(reader: stub, interval: 999)
        stub.snapshot = makeSnapshot(percent: 90)
        monitor.refresh()
        XCTAssertEqual(monitor.snapshot.percent, 90)
    }

    // MARK: - Helpers

    private func makeSnapshot(percent: Int) -> BatterySnapshot {
        BatterySnapshot(
            percent: percent,
            isCharging: false,
            isPluggedIn: false,
            minutesRemaining: nil,
            hasBattery: true
        )
    }

    private final class StubReader: PowerSourceReading {
        var snapshot: BatterySnapshot
        init(snapshot: BatterySnapshot) { self.snapshot = snapshot }
        func read() -> BatterySnapshot { snapshot }
    }
}
