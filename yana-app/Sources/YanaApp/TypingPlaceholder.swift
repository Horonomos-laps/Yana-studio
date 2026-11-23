import SwiftUI

// On the empty chat the box's hint types itself out, one example request after another, like the "Describe your
// idea" box in the design tool's video: it types a sentence, holds it for a moment, clears, and moves to the next. The
// examples are the same four requests as the suggestion cards, so each one really works. The time to show comes from
// a pure function, so what is on screen at any moment can be tested.

enum TypingPlaceholder {
	static let charsPerSecond = 32.0
	static let holdSeconds = 2.6
	static let gapSeconds = 0.5

	// Whether the typing hint is on: only on an empty chat with an empty box, when the suggestions are switched on,
	// and never for someone who asked macOS to reduce motion.
	static func isActive(text: String, chatIsEmpty: Bool, enabled: Bool, reduceMotion: Bool) -> Bool {
		text.isEmpty && chatIsEmpty && enabled && !reduceMotion
	}

	static func typingSeconds(_ example: String) -> Double { Double(example.count) / charsPerSecond }
	static func cycleSeconds(_ example: String) -> Double { typingSeconds(example) + holdSeconds + gapSeconds }

	// What the hint shows `t` seconds into the loop through `examples`.
	static func text(at t: Double, examples: [String]) -> String {
		guard !examples.isEmpty, t >= 0 else { return "" }
		let total = examples.reduce(0) { $0 + cycleSeconds($1) }
		var offset = t.truncatingRemainder(dividingBy: total)
		for example in examples {
			let typing = typingSeconds(example)
			if offset < typing { return String(example.prefix(Int(offset * charsPerSecond))) }
			if offset < typing + holdSeconds { return example }
			if offset < cycleSeconds(example) { return "" }
			offset -= cycleSeconds(example)
		}
		return ""
	}
}

struct TypingPlaceholderView: View {
	let examples: [String]
	// The loop starts when the view appears, so the first thing seen is the start of a sentence being typed.
	@State private var started = Date()

	var body: some View {
		TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
			Text(TypingPlaceholder.text(at: context.date.timeIntervalSince(started), examples: examples))
				.font(.system(size: 15)).foregroundStyle(FB.textTertiary)
				.lineLimit(2)
				.frame(maxWidth: .infinity, alignment: .leading)
		}
		.onAppear { started = Date() }
		.accessibilityHidden(true)
	}
}
