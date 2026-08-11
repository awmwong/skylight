@testable import Skylight
import XCTest

final class SmokeTests: XCTestCase {
    func testAppInfoNamesAreStable() {
        XCTAssertEqual(AppInfo.name, "Skylight")
        XCTAssertEqual(AppInfo.virtualDisplayName, "Skylight Display")
    }
}
