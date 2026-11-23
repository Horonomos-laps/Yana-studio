import XCTest
@testable import YanaApp

final class ClipboardTests: XCTestCase {
	private func fill(_ n: Int) -> [ClipItem] {
		var items: [ClipItem] = []
		for i in 0 ..< n { items = ClipboardHistory.insert(items, text: "t\(i)") }
		return items
	}

	func testAPinnedItemSurvivesTheLimitAndKeepsItsPinWhenCopiedAgain() {
		var items = fill(5)
		items = ClipboardHistory.togglePin(items, id: items.last!.id)       // pins "t0", the oldest
		for i in 100 ..< 150 { items = ClipboardHistory.insert(items, text: "t\(i)") }
		XCTAssertTrue(items.contains { $0.text == "t0" && $0.pinned }, "pinned is never dropped")
		XCTAssertEqual(items.filter { !$0.pinned }.count, ClipboardHistory.limit)
		items = ClipboardHistory.insert(items, text: "t0")
		XCTAssertEqual(items.first?.text, "t0"); XCTAssertTrue(items.first?.pinned == true, "moves up and stays pinned")
	}

	func testTheSourceAppIsKeptAndNotLostWhenTheSameTextIsCopiedFromNowhere() {
		var items = ClipboardHistory.insert([], text: "a", app: "Safari")
		items = ClipboardHistory.insert(items, text: "a")
		XCTAssertEqual(items.first?.app, "Safari")
		items = ClipboardHistory.insert(items, text: "a", app: "Notes"); XCTAssertEqual(items.first?.app, "Notes")
	}

	func testFilterByPinAndBySearchIgnoringCaseAndAccents() {
		var items = ClipboardHistory.insert([], text: "Xin chào thế giới", app: "Notes")
		items = ClipboardHistory.insert(items, text: "hello world", app: "Safari")
		items = ClipboardHistory.togglePin(items, id: items[0].id)
		XCTAssertEqual(ClipboardHistory.filter(items, pinnedOnly: true, query: "").map(\.text), ["hello world"])
		XCTAssertEqual(ClipboardHistory.filter(items, pinnedOnly: false, query: "CHAO").map(\.text), ["Xin chào thế giới"], "case and accents ignored")
		XCTAssertEqual(ClipboardHistory.filter(items, pinnedOnly: false, query: "safari").count, 1, "the app name is searched too")
		XCTAssertEqual(ClipboardHistory.filter(items, pinnedOnly: false, query: "xin gioi").count, 1, "all words must match, in any order")
		XCTAssertEqual(ClipboardHistory.filter(items, pinnedOnly: false, query: "zzz").count, 0)
		XCTAssertEqual(ClipboardHistory.filter(items, pinnedOnly: false, query: "   ").count, 2, "a blank search shows everything")
	}

	func testRemoveAndAnOlderSavedListStillLoads() throws {
		var items = fill(3)
		items = ClipboardHistory.remove(items, id: items[1].id); XCTAssertEqual(items.count, 2)
		let old = "[{\"id\":\"E621E1F8-C36C-495A-93FC-0C247A3E6E5F\",\"text\":\"saved\",\"date\":0}]"
		let loaded = try JSONDecoder().decode([ClipItem].self, from: Data(old.utf8))
		XCTAssertEqual(loaded.first?.text, "saved"); XCTAssertEqual(loaded.first?.pinned, false); XCTAssertNil(loaded.first?.app)
		let round = try JSONDecoder().decode([ClipItem].self, from: JSONEncoder().encode(items))
		XCTAssertEqual(round, items)
	}
}
