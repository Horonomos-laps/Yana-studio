import XCTest
@testable import YanaApp

final class AppshotTests: XCTestCase {
	private let me: pid_t = 100

	private func win(_ id: UInt32, _ owner: String, title: String = "", pid: pid_t = 200, layer: Int = 0,
	                 alpha: Double = 1, w: Double = 800, h: Double = 600) -> AppshotWindow {
		AppshotWindow(id: id, owner: owner, title: title, pid: pid, layer: layer, alpha: alpha, width: w, height: h)
	}

	func testPicksTheFirstWindowThatIsNotYanas() {
		let list = [win(1, "Yana", pid: 100), win(2, "Safari", title: "Docs", pid: 201), win(3, "Notes", pid: 202)]
		XCTAssertEqual(Appshot.pickTarget(from: list, excludingPID: me)?.id, 2)
	}

	func testSkipsMenuBarsDockAndOtherSystemWindows() {
		let list = [win(1, "Window Server", layer: 25), win(2, "Dock", pid: 300), win(3, "Control Center", pid: 301),
		            win(4, "Notification Center", pid: 302), win(5, "Finder", pid: 303)]
		XCTAssertEqual(Appshot.pickTarget(from: list, excludingPID: me)?.id, 5)
	}

	func testSkipsFloatingLayersInvisibleAndTinyWindows() {
		let list = [win(1, "Tool", layer: 3), win(2, "Ghost", alpha: 0), win(3, "Badge", w: 40, h: 40),
		            win(4, "Strip", w: 900, h: 20), win(5, "Xcode", pid: 204)]
		XCTAssertEqual(Appshot.pickTarget(from: list, excludingPID: me)?.id, 5)
	}

	func testNilWhenOnlyYanaIsOnScreen() {
		XCTAssertNil(Appshot.pickTarget(from: [win(1, "Yana", pid: 100), win(2, "Yana", pid: 100)], excludingPID: me))
		XCTAssertNil(Appshot.pickTarget(from: [], excludingPID: me))
	}

	func testTheFrontToBackOrderDecides() {
		let list = [win(1, "Mail", pid: 201), win(2, "Safari", pid: 202)]
		XCTAssertEqual(Appshot.pickTarget(from: list, excludingPID: me)?.owner, "Mail")
	}

	func testFileNameNamesTheAppAndPageWithoutPathCharacters() {
		XCTAssertEqual(Appshot.fileName(owner: "Safari", title: "Docs"), "Appshot - Safari - Docs.png")
		XCTAssertEqual(Appshot.fileName(owner: "Safari", title: "a/b:c*d?e"), "Appshot - Safari - a b c d e.png")
		XCTAssertEqual(Appshot.fileName(owner: "Notes", title: ""), "Appshot - Notes.png")
		XCTAssertEqual(Appshot.fileName(owner: "", title: ""), "Appshot.png")
	}

	func testLongTitlesAreCut() {
		let name = Appshot.fileName(owner: "Safari", title: String(repeating: "x", count: 300))
		XCTAssertLessThanOrEqual(name.count, "Appshot - Safari - ".count + 60 + ".png".count)
	}

	func testFailuresHaveTextAndPermissionPointsToScreenRecording() {
		for failure in [AppshotFailure.needsPermission, .noWindow] {
			let key = try? XCTUnwrap(failure.messageKey)
			XCTAssertNotEqual(L(key ?? ""), key)
		}
		XCTAssertNil(AppshotFailure.captureFailed("x").messageKey)
		XCTAssertTrue(AppshotFailure.settingsURL?.absoluteString.hasSuffix("Privacy_ScreenCapture") ?? false)
	}

	func testAppshotShortcutIsBoundAndMapsToAMenuAction() {
		let store = ShortcutStore(defaults: UserDefaults(suiteName: "yana.tests.\(UUID().uuidString)")!)
		XCTAssertEqual(store.effective(.appshot)?.display, "⌥⌘A")
		XCTAssertNotNil(MenuAction(rawValue: ShortcutAction.appshot.rawValue))
	}

	// The window list itself needs no permission for names and sizes, so this runs anywhere that has a screen.
	func testTheLiveWindowListIsReadable() {
		let list = Appshot.onScreenWindows()
		XCTAssertTrue(list.allSatisfy { $0.width >= 0 && $0.height >= 0 })
	}
}
