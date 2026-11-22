import XCTest
@testable import YanaApp

final class RainbowTextTests: XCTestCase {
	func testThereAreSevenDistinctColors() {
		XCTAssertEqual(RainbowText.hexes.count, 7)
		XCTAssertEqual(Set(RainbowText.hexes).count, 7)
	}

	func testThePhaseLoopsEveryThreeSecondsAndStaysBelowOne() {
		XCTAssertEqual(RainbowText.phase(at: 0), 0)
		XCTAssertEqual(RainbowText.phase(at: 1.5), 0.5, accuracy: 0.0001)
		XCTAssertEqual(RainbowText.phase(at: 1.2), RainbowText.phase(at: 1.2 + RainbowText.loopSeconds), accuracy: 0.0001)
		for i in 0 ..< 1000 { XCTAssertLessThan(RainbowText.phase(at: Double(i) * 0.0731), 1) }
		XCTAssertGreaterThanOrEqual(RainbowText.phase(at: -0.5), 0, "a time before the start still gives a valid phase")
	}

	func testTheGradientRepeatsItsSevenColorsAndEndsWhereItStarted() {
		let stops = RainbowText.stops()
		XCTAssertEqual(stops.count, 7 * RainbowText.cycles + 1)
		XCTAssertEqual(stops.first?.location, 0); XCTAssertEqual(stops.last?.location, 1)
		for pair in zip(stops, stops.dropFirst()) { XCTAssertLessThan(pair.0.location, pair.1.location, "in order") }
		XCTAssertEqual(stops[0].color, stops[7].color, "the second cycle starts with the first color again")
		XCTAssertEqual(stops.first?.color, stops.last?.color, "no seam at the ends")
	}

	func testTheGradientSlidesByExactlyOneCycleOverALoopSoTheEndEqualsTheStart() {
		let start = RainbowText.points(phase: 0), end = RainbowText.points(phase: 1)
		XCTAssertEqual(end.start.x - start.start.x, 1, accuracy: 0.0001)
		XCTAssertEqual(end.end.x - start.end.x, 1, accuracy: 0.0001)
		// One cycle is a third of the gradient's length, in text widths: sliding one cycle is a full loop.
		let cycleWidth = (start.end.x - start.start.x) / Double(RainbowText.cycles)
		XCTAssertEqual(cycleWidth, 1, accuracy: 0.0001)
	}

	func testAtPhaseZeroTheTextSeesExactlyOneWholeCycle() {
		let p = RainbowText.points(phase: 0)
		let length = p.end.x - p.start.x
		XCTAssertEqual((0 - p.start.x) / length, 1.0 / 3.0, accuracy: 0.0001)
		XCTAssertEqual((1 - p.start.x) / length, 2.0 / 3.0, accuracy: 0.0001)
	}

	func testTheLettersAppearOneByOneAndThenStay() {
		XCTAssertEqual(RainbowText.revealed(at: 0, count: 4), 1)
		XCTAssertEqual(RainbowText.revealed(at: RainbowText.letterSeconds * 1.5, count: 4), 2)
		XCTAssertEqual(RainbowText.revealed(at: RainbowText.letterSeconds * 3.5, count: 4), 4)
		XCTAssertEqual(RainbowText.revealed(at: 100, count: 4), 4, "never more than the word has")
		XCTAssertEqual(RainbowText.revealed(at: -1, count: 4), 0)
		XCTAssertEqual(RainbowText.revealed(at: 1, count: 0), 0)
	}
}
