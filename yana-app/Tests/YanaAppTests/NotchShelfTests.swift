import XCTest
@testable import YanaApp

final class NotchShelfTests: XCTestCase {
	private let now = Date(timeIntervalSince1970: 1_000_000)
	private func file(_ name: String) -> URL { URL(fileURLWithPath: "/tmp/\(name)") }

	func testNewestFirstAndNoDoubles() {
		var items = Shelf.adding([file("a"), file("b")], to: [], now: now)
		XCTAssertEqual(items.map(\.path), ["/tmp/a", "/tmp/b"])
		items = Shelf.adding([file("b")], to: items, now: now.addingTimeInterval(5))
		XCTAssertEqual(items.map(\.path), ["/tmp/b", "/tmp/a"])
		XCTAssertEqual(Shelf.adding([file("c"), file("c")], to: [], now: now).count, 1)
	}

	func testOnlyFilesAreKept() {
		let web = URL(string: "https://example.com/a")!
		XCTAssertTrue(Shelf.adding([web], to: [], now: now).isEmpty)
		XCTAssertTrue(Shelf.adding([], to: [], now: now).isEmpty)
	}

	func testTheShelfHasALimit() {
		let many = (0 ..< 10_000).map { file("f\($0)") }
		XCTAssertEqual(Shelf.adding(many, to: [], now: now).count, Shelf.limit)
	}

	func testOldAndMissingItemsLeave() {
		let items = Shelf.adding([file("a"), file("b")], to: [], now: now)
		XCTAssertEqual(Shelf.kept(items, now: now.addingTimeInterval(Shelf.lifetime - 1)) { _ in true }.count, 2)
		XCTAssertTrue(Shelf.kept(items, now: now.addingTimeInterval(Shelf.lifetime + 1)) { _ in true }.isEmpty)
		XCTAssertEqual(Shelf.kept(items, now: now) { $0 == "/tmp/b" }.map(\.path), ["/tmp/b"])
	}

	func testOddNamesSurvive() {
		let odd = [file("có dấu 🔥.txt"), file("a b;$(id).txt"), file(String(repeating: "n", count: 200))]
		let items = Shelf.adding(odd, to: [], now: now)
		XCTAssertEqual(items.map { $0.url.path }, odd.map(\.path))
		let saved = try! JSONEncoder().encode(items)
		XCTAssertEqual(try! JSONDecoder().decode([ShelfItem].self, from: saved), items)
	}

	func testWhatTheActionsApplyTo() {
		let items = Shelf.adding([file("a"), file("b")], to: [], now: now)
		XCTAssertEqual(Shelf.targets(items, selected: []).count, 2)
		XCTAssertEqual(Shelf.targets(items, selected: ["/tmp/b"]).map(\.path), ["/tmp/b"])
		XCTAssertEqual(Shelf.targets(items, selected: ["/tmp/gone"]).count, 2)
	}

	func testADragOfFilesIsToldFromOtherDrags() {
		XCTAssertTrue(Shelf.isFileDrag(countAtMouseDown: 4, countNow: 5, carriesFiles: true))
		XCTAssertFalse(Shelf.isFileDrag(countAtMouseDown: 5, countNow: 5, carriesFiles: true), "an old drag left on the pasteboard")
		XCTAssertFalse(Shelf.isFileDrag(countAtMouseDown: 4, countNow: 5, carriesFiles: false))
		let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
		XCTAssertTrue(Shelf.dropZone(screenFrame: screen).contains(CGPoint(x: 756, y: 981)))
		XCTAssertFalse(Shelf.dropZone(screenFrame: screen).contains(CGPoint(x: 756, y: 800)))
		XCTAssertFalse(Shelf.dropZone(screenFrame: screen).contains(CGPoint(x: 100, y: 981)))
	}

	@MainActor
	func testAPageRequestIsTakenOnce() {
		_ = PageRequest.take()
		XCTAssertNil(PageRequest.take())
		PageRequest.open("Chat")
		PageRequest.open("Settings")
		XCTAssertEqual(PageRequest.take(), "Settings", "the latest wins")
		XCTAssertNil(PageRequest.take())
	}
}
