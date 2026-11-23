import XCTest
@testable import YanaApp

final class TourTests: XCTestCase {
	func testEveryPageHasAUniqueIdAndATitleAndBodyInAllThreeLanguages() {
		let pages = OnboardingTour.pages
		XCTAssertEqual(Set(pages.map(\.id)).count, pages.count)
		for page in pages {
			for key in ["tour.\(page.id).title", "tour.\(page.id).body"] {
				let row = allStringRows.first { $0.key == key }
				XCTAssertNotNil(row, key)
				if let row { XCTAssertFalse(row.vi.isEmpty || row.en.isEmpty || row.ko.isEmpty, key) }
			}
		}
	}

	func testTheGuideCoversTheNewFeatures() {
		let ids = OnboardingTour.pages.map(\.id)
		for id in ["chats", "voice", "shortcuts", "look"] { XCTAssertTrue(ids.contains(id), id) }
		XCTAssertEqual(OnboardingTour.pages.filter { $0.badge != nil }.map(\.id), ["chats", "voice", "shortcuts", "look"])
	}

	func testSomeoneWhoSawTheOldGuideStartsAtTheFirstNewPage() {
		let first = OnboardingTour.pages.firstIndex { $0.id == "chats" }!
		XCTAssertEqual(OnboardingTour.startIndex(legacySeen: true, seen: false), first)
	}

	func testANewPersonAndSomeoneWhoSawTheNewGuideStartAtTheBeginning() {
		XCTAssertEqual(OnboardingTour.startIndex(legacySeen: false, seen: false), 0)
		XCTAssertEqual(OnboardingTour.startIndex(legacySeen: true, seen: true), 0, "reopened from Help")
	}

	func testTheShortcutsPageShowsRealDefaultsThatAreAllDistinct() {
		let shown: [ShortcutAction] = [.newChat, .toggleChatList, .pinChat, .dictate, .appshot]
		let keys = shown.map { $0.defaultShortcut.display }
		XCTAssertEqual(Set(keys).count, keys.count)
		XCTAssertTrue(keys.allSatisfy { !$0.isEmpty })
	}

	func testTheGuideOfThePluginStoreIsUntouched() {
		XCTAssertEqual(StoreTour.pages.count, 4)
	}
}
