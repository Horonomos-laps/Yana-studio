import XCTest
@testable import YanaApp

final class YanaMascotTests: XCTestCase {
	func testTheSpriteIsTwentyByFifteenAndUsesOnlyKnownColors() {
		XCTAssertEqual(Mascot.base.count, Mascot.rows)
		for row in Mascot.base {
			XCTAssertEqual(row.count, Mascot.columns)
			for ch in row where ch != "." { XCTAssertNotNil(Mascot.palette[ch], "unknown pixel \(ch)") }
		}
	}

	func testEarsLeanLeftAndRightAndStayInsideTheCanvas() {
		let shifts = Set((0 ..< 40).map { Mascot.earShift(tick: $0) })
		XCTAssertEqual(shifts, [-1, 0, 1])
		for tick in 0 ..< 40 {
			for cell in Mascot.cells(tick: tick, working: true, accent: 0x22C55E) {
				XCTAssertTrue((0 ..< Mascot.columns).contains(cell.x)); XCTAssertTrue((0 ..< Mascot.rows).contains(cell.y))
			}
		}
	}

	func testTheEyesBlinkOnlyOnSomeTicks() {
		let blinks = (0 ..< 60).filter { Mascot.blinking(tick: $0) }
		XCTAssertEqual(blinks.count, 4)
		let open = Mascot.cells(tick: 1, working: false, accent: 0).filter { $0.y == 6 && $0.color == 0x1B2340 }.count
		let closed = Mascot.cells(tick: 0, working: false, accent: 0).filter { $0.y == 6 && $0.color == 0x1B2340 }.count
		XCTAssertEqual(open, 4); XCTAssertEqual(closed, 0)
	}

	func testTheTypingPixelSweepsTheScreenOnlyWhileWorking() {
		let columns = Set((0 ..< 44).map { Mascot.typingColumn(tick: $0) })
		XCTAssertEqual(columns, Set(0 ..< 12))
		let lit = { (tick: Int, working: Bool) in Mascot.cells(tick: tick, working: working, accent: 0xABCDEF).filter { $0.color == 0xABCDEF }.count }
		XCTAssertEqual(lit(3, true), 3, "one column of the three screen rows")
		XCTAssertEqual(lit(3, false), 0, "idle does not type")
	}
}
