import XCTest
@testable import YanaApp

final class ChatSectionsTests: XCTestCase {
	private func chat(_ id: String, _ title: String, age: TimeInterval, pinned: Bool = false, text: String = "hi") -> SavedChat {
		SavedChat(id: id, title: title, updated: Date(timeIntervalSince1970: 1_000_000 - age), provider: "p", model: nil,
		          lines: [SavedLine(user: true, text: text)], customTitle: nil, pinned: pinned ? true : nil)
	}

	func testPinnedGoFirstAndEachGroupIsNewestFirst() {
		let list = [chat("a", "A", age: 30), chat("b", "B", age: 10, pinned: true), chat("c", "C", age: 20),
		            chat("d", "D", age: 5, pinned: true)]
		let sections = ChatSections.build(chats: list, query: "", showAllRecent: false)
		XCTAssertEqual(sections.map(\.kind), [.pinned, .recent])
		XCTAssertEqual(sections[0].chats.map(\.id), ["d", "b"])
		XCTAssertEqual(sections[1].chats.map(\.id), ["c", "a"])
	}

	func testEmptyGroupsAreLeftOut() {
		XCTAssertEqual(ChatSections.build(chats: [chat("a", "A", age: 1)], query: "", showAllRecent: false).map(\.kind), [.recent])
		XCTAssertEqual(ChatSections.build(chats: [chat("a", "A", age: 1, pinned: true)], query: "", showAllRecent: false).map(\.kind), [.pinned])
		XCTAssertTrue(ChatSections.build(chats: [], query: "", showAllRecent: false).isEmpty)
	}

	func testLongRecentListIsCutAndCountsTheRest() {
		let list = (0 ..< 45).map { chat("c\($0)", "T\($0)", age: TimeInterval($0)) }
		let cut = ChatSections.build(chats: list, query: "", showAllRecent: false)
		XCTAssertEqual(cut[0].chats.count, 30)
		XCTAssertEqual(cut[0].hidden, 15)
		XCTAssertEqual(cut[0].chats.first?.id, "c0")
		let all = ChatSections.build(chats: list, query: "", showAllRecent: true)
		XCTAssertEqual(all[0].chats.count, 45)
		XCTAssertEqual(all[0].hidden, 0)
	}

	func testPinnedIsNeverCut() {
		let list = (0 ..< 40).map { chat("p\($0)", "P\($0)", age: TimeInterval($0), pinned: true) }
		let sections = ChatSections.build(chats: list, query: "", showAllRecent: false)
		XCTAssertEqual(sections[0].chats.count, 40)
		XCTAssertEqual(sections[0].hidden, 0)
	}

	func testSearchFiltersBothGroupsAndIgnoresTheLimit() {
		var list = (0 ..< 40).map { chat("c\($0)", "match \($0)", age: TimeInterval($0)) }
		list.append(chat("p", "pinned match", age: 100, pinned: true))
		list.append(chat("x", "other", age: 1, text: "nothing here"))
		let sections = ChatSections.build(chats: list, query: "Match", showAllRecent: false)
		XCTAssertEqual(sections[0].chats.map(\.id), ["p"])
		XCTAssertEqual(sections[1].chats.count, 40)
		XCTAssertEqual(sections[1].hidden, 0)
	}

	func testSearchFindsTextInMessagesAndIgnoresAccents() {
		let list = [chat("a", "Tiêu đề", age: 1, text: "Sửa lỗi đăng nhập")]
		XCTAssertEqual(ChatSections.build(chats: list, query: "sua loi", showAllRecent: false).first?.chats.count, 1)
		XCTAssertTrue(ChatSections.build(chats: list, query: "zzz", showAllRecent: false).isEmpty)
	}

	func testPinChatShortcutIsBoundAndFree() {
		XCTAssertEqual(ShortcutStore(defaults: UserDefaults(suiteName: "yana.tests.\(UUID().uuidString)")!).effective(.pinChat)?.display, "⌥⌘P")
		XCTAssertNotNil(MenuAction(rawValue: ShortcutAction.pinChat.rawValue))
	}
}
