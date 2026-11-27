import XCTest
@testable import YanaApp

final class NotchGestureTests: XCTestCase {
	func testNaturalAndClassicScrollingGiveTheSameFingerDirection() {
		XCTAssertEqual(SwipeAccumulator.fingers(dx: 3, dy: 5, inverted: true), CGSize(width: 3, height: 5))
		XCTAssertEqual(SwipeAccumulator.fingers(dx: -3, dy: -5, inverted: false), CGSize(width: 3, height: 5))
	}

	func testOneGestureGivesOneSwipe() {
		var swipe = SwipeAccumulator()
		XCTAssertNil(swipe.add(CGSize(width: 0, height: 12)))
		XCTAssertEqual(swipe.add(CGSize(width: 0, height: 12)), .down)
		XCTAssertNil(swipe.add(CGSize(width: 0, height: 90)))
		swipe.begin()
		XCTAssertEqual(swipe.add(CGSize(width: 0, height: -25)), .up)
	}

	func testSidewaysNeedsToBeClearlySideways() {
		var swipe = SwipeAccumulator()
		XCTAssertNil(swipe.add(CGSize(width: 39, height: 0)))
		XCTAssertEqual(swipe.add(CGSize(width: 5, height: 0)), .right)
		swipe.begin()
		XCTAssertEqual(swipe.add(CGSize(width: -50, height: 10)), .left)
		swipe.begin()
		XCTAssertEqual(swipe.add(CGSize(width: 45, height: 30)), .down, "mostly diagonal counts as vertical")
	}

	func testEmptyAndHugeMovementsAreSafe() {
		var swipe = SwipeAccumulator()
		XCTAssertNil(swipe.add(.zero))
		XCTAssertNil(swipe.add(CGSize(width: CGFloat.nan, height: CGFloat.infinity)))
		XCTAssertEqual(swipe.add(CGSize(width: 0, height: 1e9)), .down)
	}

	func testWhatASwipeDoesClosed() {
		func act(_ s: NotchSwipe, music: Bool) -> NotchSwipeAction? {
			NotchSwipeAction.of(s, open: false, inHeader: true, contentScrolls: false, hasMusic: music)
		}
		XCTAssertEqual(act(.down, music: false), .open)
		XCTAssertEqual(act(.left, music: true), .nextTrack)
		XCTAssertEqual(act(.right, music: true), .previousTrack)
		XCTAssertNil(act(.left, music: false))
		XCTAssertNil(act(.up, music: true))
	}

	func testWhatASwipeDoesOpenLeavesListsAlone() {
		func act(_ s: NotchSwipe, header: Bool, scrolls: Bool) -> NotchSwipeAction? {
			NotchSwipeAction.of(s, open: true, inHeader: header, contentScrolls: scrolls, hasMusic: true)
		}
		XCTAssertEqual(act(.up, header: true, scrolls: false), .close)
		XCTAssertNil(act(.up, header: false, scrolls: false), "scrolling a list must not close the notch")
		XCTAssertEqual(act(.left, header: false, scrolls: false), .nextPage)
		XCTAssertEqual(act(.right, header: true, scrolls: true), .previousPage)
		XCTAssertNil(act(.left, header: false, scrolls: true), "a sideways list keeps its own scrolling")
		XCTAssertNil(act(.down, header: true, scrolls: false))
	}

	func testPagesStopAtBothEnds() {
		XCTAssertEqual(NotchTab.yana.moved(by: -1), .yana)
		XCTAssertEqual(NotchTab.yana.moved(by: 1), NotchTab.allCases[1])
		XCTAssertEqual(NotchTab.allCases.last!.moved(by: 1), NotchTab.allCases.last!)
	}

	func testPanelSizesFitTheWindow() {
		for size in NotchSize.allCases {
			let geometry = NotchGeometry(notch: CGSize(width: 200, height: 32), panel: size)
			XCTAssertEqual(geometry.size(.open), size.open)
			XCTAssertLessThan(size.open.height + 30, NotchGeometry.windowHeight)
		}
		XCTAssertEqual(NotchGeometry(notch: nil).size(.open), NotchGeometry.openSize)
		for bad in [nil, "", "huge", String(repeating: "x", count: 65536)] { XCTAssertEqual(NotchSize.from(bad), .regular) }
	}
}
