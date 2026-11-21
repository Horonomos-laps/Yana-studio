import XCTest
@testable import YanaApp

final class LeftSideTests: XCTestCase {
	private func defaults() -> UserDefaults {
		let name = "yana.tests.left.\(UUID().uuidString)"
		let d = UserDefaults(suiteName: name)!
		d.removePersistentDomain(forName: name)
		return d
	}

	func testTheRailIsHiddenOnlyOnTheChatPageAndOnlyWhenAsked() {
		XCTAssertFalse(LeftSide.railVisible(hidden: true, page: "Chat"))
		XCTAssertTrue(LeftSide.railVisible(hidden: false, page: "Chat"))
	}

	func testEveryOtherPageKeepsTheRailSoThereIsAlwaysAWayToNavigate() {
		for entry in railEntries where entry.id != "Chat" { XCTAssertTrue(LeftSide.railVisible(hidden: true, page: entry.id), entry.id) }
		XCTAssertTrue(LeftSide.railVisible(hidden: true, page: "Settings"))
	}

	func testTheWindowButtonsAreToldWhetherTheRailIsShown() {
		let d = defaults()
		XCTAssertTrue(LeftSide.railShown(d), "with nothing stored the rail counts as shown")
		LeftSide.publish(hidden: true, page: "Chat", defaults: d)
		XCTAssertFalse(LeftSide.railShown(d))
		LeftSide.publish(hidden: true, page: "Usage", defaults: d)
		XCTAssertTrue(LeftSide.railShown(d))
		LeftSide.publish(hidden: false, page: "Chat", defaults: d)
		XCTAssertTrue(LeftSide.railShown(d))
	}
}
