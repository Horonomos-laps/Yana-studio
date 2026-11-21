import XCTest
@testable import YanaApp

final class ChatSuggestionTests: XCTestCase {
	func testThereAreFourCardsWithDistinctIds() {
		XCTAssertEqual(ChatSuggestion.all.count, 4)
		XCTAssertEqual(Set(ChatSuggestion.all.map(\.id)).count, 4)
	}

	func testEveryCardHasAnIconThatExists() {
		for item in ChatSuggestion.all { XCTAssertNotNil(FBIcons.markup[item.icon], item.id) }
	}

	func testEveryCardHasATitleAndASentenceInAllThreeLanguages() {
		for item in ChatSuggestion.all {
			for key in [item.titleKey, item.promptKey] {
				let row = allStringRows.first { $0.key == key }
				XCTAssertNotNil(row, key)
				if let row {
					XCTAssertFalse(row.vi.isEmpty, key); XCTAssertFalse(row.en.isEmpty, key); XCTAssertFalse(row.ko.isEmpty, key)
				}
			}
		}
	}

	func testTheTitleStaysShortAndTheSentenceIsAFullRequest() {
		for item in ChatSuggestion.all {
			XCTAssertLessThanOrEqual(L(item.titleKey).count, 30, item.id)
			XCTAssertGreaterThan(L(item.promptKey).count, 40, item.id)
		}
	}

	func testCardsShowOnlyOnAnEmptyChatWithNothingTyped() {
		XCTAssertTrue(ChatSuggestion.visible(chatIsEmpty: true, draft: ""))
		XCTAssertTrue(ChatSuggestion.visible(chatIsEmpty: true, draft: "  \n "))
		XCTAssertFalse(ChatSuggestion.visible(chatIsEmpty: true, draft: "viết giúp tôi"), "never over a draft")
		XCTAssertFalse(ChatSuggestion.visible(chatIsEmpty: false, draft: ""))
	}

	func testNoStringKeyIsDefinedTwice() {
		let keys = allStringRows.map(\.key)
		XCTAssertEqual(keys.count, Set(keys).count)
	}
}
