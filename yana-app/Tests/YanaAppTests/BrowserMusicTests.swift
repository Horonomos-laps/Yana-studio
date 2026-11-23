import XCTest
@testable import YanaApp

final class BrowserMusicTests: XCTestCase {
	func testTheReadScriptNamesTheAppIsSafeInsideAnAppleScriptStringAndNeverLaunchesTheApp() {
		let s = BrowserMusic.script(app: "Google Chrome", js: BrowserMusic.readJS)
		XCTAssertTrue(s.contains("application \"Google Chrome\" is running"))
		XCTAssertTrue(s.contains("execute t javascript"))
		XCTAssertFalse(BrowserMusic.readJS.contains("\""), "a double quote would end the AppleScript string")
		XCTAssertFalse(BrowserMusic.readJS.contains("\\"), "a backslash would be read as an escape")
		for command in [BrowserMusic.Command.playPause, .next, .previous] {
			XCTAssertFalse(BrowserMusic.js(for: command).contains("\""))
		}
	}

	func testSafariUsesItsOwnJavaScriptCall() {
		let s = BrowserMusic.script(app: "Safari", js: "1")
		XCTAssertTrue(s.contains("do JavaScript \"1\" in t")); XCTAssertFalse(s.contains("execute t javascript"))
	}

	func testOnlyYouTubePagesAreRead() {
		let s = BrowserMusic.script(app: "Arc", js: "1")
		XCTAssertTrue(s.contains("youtube.com/watch")); XCTAssertTrue(s.contains("music.youtube.com"))
	}

	func testAFailureIsExplainedAsAutomationOrTheBrowsersJavaScriptSwitch() {
		XCTAssertEqual(BrowserMusic.problem(code: -1743, message: "Not authorized", app: "Safari"), .automationRefused)
		XCTAssertEqual(BrowserMusic.problem(code: 12, message: "Executing JavaScript through AppleScript is turned off. To turn it on, from the menu bar, select View > Developer > Allow JavaScript from Apple Events.", app: "Google Chrome"),
		               .javascriptOff(app: "Google Chrome"))
		XCTAssertNil(BrowserMusic.problem(code: -1728, message: "Can't get window 1", app: "Arc"))
		XCTAssertTrue(BrowserMusic.switchHint(app: "Safari").contains("Develop"))
		XCTAssertTrue(BrowserMusic.switchHint(app: "Brave Browser").contains("View"))
	}

	func testAYouTubeLineIsReadInSecondsWithItsThumbnailAndRejectsOtherAddresses() {
		let sep = NowPlaying.separator
		let raw = ["playing", "Nhạc buồn", "Một Kênh", "215.5", "12.25", "https://i.ytimg.com/vi/abc/hqdefault.jpg"].joined(separator: sep)
		let now = NowPlaying.parse(raw, source: .chrome)
		XCTAssertEqual(now?.title, "Nhạc buồn"); XCTAssertEqual(now?.duration, 215.5, "seconds, not milliseconds")
		XCTAssertEqual(now?.source, .chrome); XCTAssertTrue(now?.source.isBrowser == true); XCTAssertNotNil(now?.artworkURL)
		let bad = ["paused", "T", "C", "NaN", "0", "javascript:alert(1)"].joined(separator: sep)
		XCTAssertNil(NowPlaying.parse(bad, source: .safari)?.artworkURL)
		XCTAssertFalse(NowPlaying.Source.spotify.isBrowser); XCTAssertEqual(NowPlaying.Source.all.count, 7)
	}
}
