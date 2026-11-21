import XCTest
@testable import YanaApp

final class PanelLayoutTests: XCTestCase {
	func testAWideWindowKeepsTheRequestedPanelWidth() {
		let s = PanelLayout.split(available: 1400, requested: 520)
		XCTAssertEqual(s.panel, 520)
		XCTAssertEqual(s.chat + s.panel + PanelLayout.handle, 1400)
	}

	// The reported bug: 1227 pt window, rail 80 and chat list 252 leave 895, and a 520 panel left ~370 for the chat.
	func testTheReportedCaseLeavesTheChatItsMinimum() {
		let s = PanelLayout.split(available: 1227 - 80 - 252, requested: 520)
		XCTAssertGreaterThanOrEqual(s.chat, PanelLayout.chatMin)
		XCTAssertEqual(s.panel, 895 - PanelLayout.handle - PanelLayout.chatMin)
	}

	func testPartsAlwaysAddUpToTheAvailableWidth() {
		for available in stride(from: 300.0, through: 2000.0, by: 37.0) {
			for requested in [100.0, 320, 520, 900, 5000] {
				let s = PanelLayout.split(available: CGFloat(available), requested: CGFloat(requested))
				XCTAssertEqual(s.chat + s.panel + PanelLayout.handle, CGFloat(available), accuracy: 0.001, "\(available)/\(requested)")
				XCTAssertGreaterThanOrEqual(s.chat, 0)
				XCTAssertGreaterThanOrEqual(s.panel, 0)
			}
		}
	}

	func testThePanelNeverExceedsWhatWasAskedOrTheMaximum() {
		XCTAssertEqual(PanelLayout.split(available: 3000, requested: 400).panel, 400)
		XCTAssertEqual(PanelLayout.split(available: 5000, requested: 9000).panel, PanelLayout.panelMax)
	}

	func testTheSmallestWindowStillShowsBothWithoutOverflow() {
		// The window's minimum is 1040; minus the rail and the chat list that is 708.
		let s = PanelLayout.split(available: 1040 - 80 - 252, requested: 520)
		// The chat keeps its 440 and the panel takes the rest, which is still above its floor.
		XCTAssertEqual(s.chat, PanelLayout.chatMin)
		XCTAssertEqual(s.panel, 708 - PanelLayout.handle - PanelLayout.chatMin)
		XCTAssertGreaterThanOrEqual(s.panel, PanelLayout.panelMin)
	}

	func testNoHandleGivesItsFiveSurplusPointsToTheChat() {
		let a = PanelLayout.split(available: 1200, requested: 520, showsHandle: true)
		let b = PanelLayout.split(available: 1200, requested: 520, showsHandle: false)
		XCTAssertEqual(a.panel, b.panel)
		XCTAssertEqual(b.chat - a.chat, PanelLayout.handle)
	}

	func testTinyOrZeroWidthDoesNotCrashOrGoNegative() {
		for available in [-50.0, 0, 10] {
			let s = PanelLayout.split(available: CGFloat(available), requested: 520)
			XCTAssertGreaterThanOrEqual(s.chat, 0)
			XCTAssertGreaterThanOrEqual(s.panel, 0)
		}
	}
}
