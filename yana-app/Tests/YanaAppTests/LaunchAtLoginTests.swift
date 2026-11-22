import ServiceManagement
import XCTest
@testable import YanaApp

final class LaunchAtLoginTests: XCTestCase {
	func testEveryMacOSStatusMapsToOneOutcome() {
		XCTAssertEqual(LaunchAtLogin.outcome(for: .enabled), .on)
		XCTAssertEqual(LaunchAtLogin.outcome(for: .notRegistered), .off)
		XCTAssertEqual(LaunchAtLogin.outcome(for: .requiresApproval), .needsApproval)
		if case .unavailable = LaunchAtLogin.outcome(for: .notFound) {} else { XCTFail("not found is unavailable") }
	}

	func testTheThreeNewStringsExistInAllLanguages() {
		for row in launchAtLoginRows {
			XCTAssertFalse(row.vi.isEmpty); XCTAssertFalse(row.en.isEmpty); XCTAssertFalse(row.ko.isEmpty)
		}
		XCTAssertEqual(launchAtLoginRows.count, 3)
	}
}
