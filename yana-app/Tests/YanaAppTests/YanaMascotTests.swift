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

	func testMotionIsSmoothNoPoseJumpsBetweenFramesThirtyToTheSecond() {
		var previous = Mascot.pose(time: 0, working: true)
		var t = 1.0 / 30
		while t < 12 {
			let next = Mascot.pose(time: t, working: true)
			XCTAssertLessThan(abs(next.ear - previous.ear), 0.3, "ears move by a fraction of a pixel per frame")
			XCTAssertLessThan(abs(next.bob - previous.bob), 0.3)
			XCTAssertLessThan(abs(next.light - previous.light), 1.0, "the typing light moves less than a pixel per frame")
			XCTAssertLessThan(abs(next.eyeOpen - previous.eyeOpen), 0.45, "the eyes close over several frames")
			previous = next; t += 1.0 / 30
		}
	}

	func testPoseStaysInRangeAndTheEyesBlink() {
		var sawShut = false
		for i in 0 ..< 3000 {
			let p = Mascot.pose(time: Double(i) / 100, working: i % 2 == 0)
			XCTAssertTrue((-0.81 ... 0.81).contains(p.ear)); XCTAssertTrue((0 ... 0.61).contains(p.bob))
			XCTAssertTrue((0 ... 1).contains(p.eyeOpen))
			XCTAssertTrue((0 ... Double(Mascot.screenColumns - 1)).contains(p.light))
			if p.eyeOpen < 0.1 { sawShut = true }
		}
		XCTAssertTrue(sawShut)
		XCTAssertEqual(Mascot.pose(time: 1.0, working: false).eyeOpen, 1, "open between blinks")
	}

	func testAllPixelsStayInsideTheCanvasAndTheSpriteIsTheSameSizeEveryFrame() {
		let count = Mascot.cells(time: 0, working: true, accent: 0x22C55E).count
		for i in 0 ..< 200 {
			let cells = Mascot.cells(time: Double(i) * 0.07, working: i % 2 == 0, accent: 0x22C55E)
			XCTAssertEqual(cells.count, count)
			for c in cells {
				XCTAssertTrue(c.x > -1 && c.x < Double(Mascot.columns)); XCTAssertTrue(c.y > -1 && c.y < Double(Mascot.rows))
			}
		}
	}

	func testTheTypingLightOnlyShowsWhileWorkingAndFadesAcrossNeighbours() {
		let accent: UInt32 = 0x22C55E
		let lid: UInt32 = 0x9AA3B2
		func tinted(_ working: Bool) -> Int {
			Mascot.cells(time: 0.3, working: working, accent: accent).filter { $0.color != lid && ($0.y >= 9.5 && $0.y <= 13) && $0.color != 0x4A5470 && $0.color != 0xEEF2FF && $0.color != 0xFF8FB1 }.count
		}
		XCTAssertGreaterThan(tinted(true), 0); XCTAssertEqual(tinted(false), 0)
		XCTAssertEqual(Mascot.mix(0x000000, 0xFFFFFF, 0.5), 0x808080); XCTAssertEqual(Mascot.mix(1, 2, 0), 1)
	}
}
