import EventKit
import XCTest
@testable import gh_notch

final class CalendarServiceTests: XCTestCase {

    // The EKAuthorizationStatus → CalendarPermission mapping is the testable part
    // of the EventKit boundary (the store/fetch needs a real calendar + TCC, which
    // CI cannot provide). `.authorized` is deliberately omitted here because it is
    // deprecated on macOS 14; it shares the granted case with `.fullAccess`.
    func testAuthorizationMapping() {
        XCTAssertEqual(CalendarPermission(.notDetermined), .notDetermined)
        XCTAssertEqual(CalendarPermission(.fullAccess), .granted)
        XCTAssertEqual(CalendarPermission(.denied), .denied)
        XCTAssertEqual(CalendarPermission(.restricted), .denied)
        XCTAssertEqual(CalendarPermission(.writeOnly), .denied)
    }
}
