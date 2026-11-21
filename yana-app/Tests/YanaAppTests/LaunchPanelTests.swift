import XCTest
@testable import YanaApp

final class LaunchPanelTests: XCTestCase {
	func testOnlyAStartPageSetToTerminalOpensThePanel() {
		XCTAssertTrue(LaunchPanel.opensTerminal(startPage: "Terminal"))
		for page in ["ask", "Start", "Chat", "Overview", "Usage", "Settings", ""] {
			XCTAssertFalse(LaunchPanel.opensTerminal(startPage: page), page)
		}
	}

	func testTheDefaultStartPageDoesNotOpenIt() {
		// A fresh install asks (the start chooser) or goes to Chat; neither opens the terminal.
		XCTAssertFalse(LaunchPanel.opensTerminal(startPage: "ask"))
		XCTAssertFalse(LaunchPanel.opensTerminal(startPage: "Chat"))
	}

	@MainActor
	func testANewTerminalStoreDoesNotAskForThePanel() {
		XCTAssertFalse(TerminalStore().wantsPanel)
	}
}
