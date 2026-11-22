import XCTest
@testable import YanaApp

final class TypingPlaceholderTests: XCTestCase {
	private let examples = ["Hello world", "Second request"]

	func testItStartsEmptyAndTypesOneLetterAtATime() {
		XCTAssertEqual(TypingPlaceholder.text(at: 0, examples: examples), "")
		let step = 1.0 / TypingPlaceholder.charsPerSecond
		XCTAssertEqual(TypingPlaceholder.text(at: step * 1.5, examples: examples), "H")
		XCTAssertEqual(TypingPlaceholder.text(at: step * 5.5, examples: examples), "Hello")
	}

	func testTheFullSentenceIsHeldLongEnoughToRead() {
		let typed = TypingPlaceholder.typingSeconds(examples[0])
		XCTAssertEqual(TypingPlaceholder.text(at: typed + 0.1, examples: examples), "Hello world")
		XCTAssertEqual(TypingPlaceholder.text(at: typed + TypingPlaceholder.holdSeconds - 0.1, examples: examples), "Hello world")
	}

	func testItClearsThenMovesOnToTheNextExample() {
		let first = TypingPlaceholder.cycleSeconds(examples[0])
		let typed = TypingPlaceholder.typingSeconds(examples[0])
		XCTAssertEqual(TypingPlaceholder.text(at: typed + TypingPlaceholder.holdSeconds + 0.1, examples: examples), "", "a pause between sentences")
		XCTAssertEqual(TypingPlaceholder.text(at: first + 0.04, examples: examples), "S")
	}

	func testItLoopsBackToTheFirstExample() {
		let total = examples.reduce(0) { $0 + TypingPlaceholder.cycleSeconds($1) }
		XCTAssertEqual(TypingPlaceholder.text(at: total + 0.05, examples: examples), TypingPlaceholder.text(at: 0.05, examples: examples))
		XCTAssertEqual(TypingPlaceholder.text(at: total * 7 + 1, examples: examples), TypingPlaceholder.text(at: 1, examples: examples))
	}

	func testTheTextOnlyEverGrowsWhileATypingStepRuns() {
		var previous = 0
		for i in 0 ..< Int(TypingPlaceholder.typingSeconds(examples[0]) * 100) {
			let length = TypingPlaceholder.text(at: Double(i) / 100, examples: examples).count
			XCTAssertGreaterThanOrEqual(length, previous); previous = length
		}
	}

	func testNothingIsShownForNoExamplesOrANegativeTime() {
		XCTAssertEqual(TypingPlaceholder.text(at: 3, examples: []), "")
		XCTAssertEqual(TypingPlaceholder.text(at: -1, examples: examples), "")
		XCTAssertEqual(TypingPlaceholder.text(at: 5, examples: [""]), "", "an empty example is just a pause")
	}

	func testItIsOnlyOnForAnEmptyChatAndBoxWithMotionAndSuggestionsAllowed() {
		XCTAssertTrue(TypingPlaceholder.isActive(text: "", chatIsEmpty: true, enabled: true, reduceMotion: false))
		XCTAssertFalse(TypingPlaceholder.isActive(text: "a", chatIsEmpty: true, enabled: true, reduceMotion: false), "never over typing")
		XCTAssertFalse(TypingPlaceholder.isActive(text: "", chatIsEmpty: false, enabled: true, reduceMotion: false))
		XCTAssertFalse(TypingPlaceholder.isActive(text: "", chatIsEmpty: true, enabled: false, reduceMotion: false))
		XCTAssertFalse(TypingPlaceholder.isActive(text: "", chatIsEmpty: true, enabled: true, reduceMotion: true), "reduce motion")
	}

	func testTheRealExamplesAreTheSuggestionCardRequestsAndAllReadInFullInUnderTwentySeconds() {
		let real = ChatSuggestion.all.map { L($0.promptKey) }
		XCTAssertEqual(real.count, 4)
		for example in real {
			XCTAssertFalse(example.isEmpty)
			XCTAssertLessThan(TypingPlaceholder.cycleSeconds(example), 12, "one sentence does not drag on")
		}
		XCTAssertLessThan(real.reduce(0) { $0 + TypingPlaceholder.cycleSeconds($1) }, 45)
	}
}
