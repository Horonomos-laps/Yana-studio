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
		for id in ["chats", "voice", "shortcuts", "look", "notch", "shelf", "keys", "update"] { XCTAssertTrue(ids.contains(id), id) }
		XCTAssertEqual(OnboardingTour.pages.filter { $0.badge != nil }.map(\.id), ["notch", "shelf", "keys", "update"])
	}

	private func start(legacy: Bool, previous: Bool, seen: Bool) -> Int {
		OnboardingTour.startIndex(legacySeen: legacy, previousSeen: previous, seen: seen)
	}
	private func index(_ id: String) -> Int { OnboardingTour.pages.firstIndex { $0.id == id }! }

	func testSomeoneWhoSawAnEarlierGuideStartsAtWhatCameAfter() {
		XCTAssertEqual(start(legacy: true, previous: true, seen: false), index("notch"))
		XCTAssertEqual(start(legacy: false, previous: true, seen: false), index("notch"))
		XCTAssertEqual(start(legacy: true, previous: false, seen: false), index("chats"), "saw only the first five")
	}

	func testANewPersonAndSomeoneWhoSawThisGuideStartAtTheBeginning() {
		XCTAssertEqual(start(legacy: false, previous: false, seen: false), 0)
		XCTAssertEqual(start(legacy: true, previous: true, seen: true), 0, "reopened from Help")
		XCTAssertEqual(OnboardingTour.startIndex(legacySeen: true, previousSeen: true, seen: false, pages: []), 0)
	}

	func testTheGuideNamesButtonsTheWayTheAppDoes() {
		func row(_ key: String) -> StringRow { allStringRows.first { $0.key == key }! }
		XCTAssertTrue(row("tour.update.body").vi.contains(row("menu.checkUpdates").vi))
		XCTAssertTrue(row("tour.update.body").en.contains(row("menu.checkUpdates").en))
		XCTAssertTrue(row("tour.keys.body").vi.contains(row("keys.share").vi))
		XCTAssertTrue(row("tour.keys.body").vi.contains(row("keys.help").vi))
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
