import XCTest
@testable import YanaApp

final class ChatExtrasTests: XCTestCase {
	func testTheNameSetInTheListWins() {
		XCTAssertEqual(ChatHeaderTitle.text(saved: "Kế hoạch quý 4", first: "câu hỏi đầu"), "Kế hoạch quý 4")
	}

	func testBeforeItIsSavedTheTitleIsTheFirstLineOfTheFirstQuestion() {
		XCTAssertEqual(ChatHeaderTitle.text(saved: nil, first: "dòng một\ndòng hai"), "dòng một")
		XCTAssertEqual(ChatHeaderTitle.text(saved: "  ", first: "  hỏi gì đó "), "hỏi gì đó")
	}

	func testALongFirstQuestionIsCut() {
		let title = ChatHeaderTitle.text(saved: nil, first: String(repeating: "a", count: 5000))
		XCTAssertEqual(title.count, ChatHeaderTitle.maxChars)
	}

	func testNothingAtAllGivesTheNewChatName() {
		XCTAssertEqual(ChatHeaderTitle.text(saved: nil, first: nil), L("chathdr.untitled"))
		XCTAssertEqual(ChatHeaderTitle.text(saved: "", first: "\n\n"), L("chathdr.untitled"))
	}

	func testTheViewStaysOnTheNewestTextOnlyWhenItWasAlreadyThereOrAMessageWasJustSent() {
		XCTAssertTrue(ScrollFollow.shouldFollow(atBottom: true, lastIsUser: false))
		XCTAssertTrue(ScrollFollow.shouldFollow(atBottom: false, lastIsUser: true))
		XCTAssertTrue(ScrollFollow.shouldFollow(atBottom: true, lastIsUser: true))
		XCTAssertFalse(ScrollFollow.shouldFollow(atBottom: false, lastIsUser: false), "do not pull someone away from what they read")
	}

	func testTheStringsExistInAllThreeLanguages() {
		for key in ["chathdr.untitled", "chathdr.menu", "chathdr.copyAll", "chathdr.scrollDown"] {
			let row = allStringRows.first { $0.key == key }
			XCTAssertNotNil(row, key)
			if let row { XCTAssertFalse(row.vi.isEmpty || row.en.isEmpty || row.ko.isEmpty, key) }
		}
	}

	func testTheIconsTheChatExtrasUseExist() {
		for name in ["more-horizontal", "arrow-down", "copy", "check"] { XCTAssertNotNil(FBIcons.markup[name], name) }
	}
}
