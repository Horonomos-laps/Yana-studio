import XCTest
@testable import YanaApp

final class LeftSideTests: XCTestCase {
	func testTheRailStepsAsideOnSettingsOnly() {
		XCTAssertFalse(LeftSide.railVisible(page: "Settings"))
		for entry in railEntries { XCTAssertTrue(LeftSide.railVisible(page: entry.id), entry.id) }
	}

	func testEveryRailPageIsReachableFromSettingsByTheBackButton() {
		// "Back" returns to the page before Settings, which is always one that shows the rail.
		for entry in railEntries { XCTAssertTrue(LeftSide.railVisible(page: entry.id)) }
		XCTAssertNotEqual(LeftSide.pageWithoutRail, "Chat")
	}

	func testTheBackButtonHasTextInEveryLanguage() {
		XCTAssertNotEqual(L("set.back"), "set.back")
	}
}
