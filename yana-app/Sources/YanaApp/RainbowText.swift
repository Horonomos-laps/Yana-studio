import SwiftUI

// A word whose letters carry the seven colors of the rainbow, drifting from left to right in a loop with no seam. The
// gradient is three cycles wide and slides by one cycle per loop, so the picture at the end of a loop is the picture at
// its start. With macOS "reduce motion" on, the colors stand still.

struct RainbowText: View {
	let text: String
	var size: CGFloat = 22
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	static let hexes: [UInt32] = [0xFF3B30, 0xFF9500, 0xF5B700, 0x34C759, 0x0A84FF, 0x5856D6, 0xAF52DE]
	static let loopSeconds = 3.0
	static let cycles = 3

	// 0 up to (not including) 1, repeating every loopSeconds.
	static func phase(at t: Double) -> Double {
		let wrapped = t.truncatingRemainder(dividingBy: loopSeconds)
		return (wrapped < 0 ? wrapped + loopSeconds : wrapped) / loopSeconds
	}

	// The same seven colors for every cycle, then the first color again at the very end, so the ends meet.
	static func stops() -> [Gradient.Stop] {
		let count = hexes.count * cycles
		var out = (0 ..< count).map { Gradient.Stop(color: Color(hex: hexes[$0 % hexes.count]), location: Double($0) / Double(count)) }
		out.append(Gradient.Stop(color: Color(hex: hexes[0]), location: 1))
		return out
	}

	// Where the gradient starts and ends, in text widths: one cycle to the left of the text at phase 0, sliding right.
	static func points(phase: Double) -> (start: UnitPoint, end: UnitPoint) {
		(UnitPoint(x: -1 + phase, y: 0.5), UnitPoint(x: Double(cycles - 1) + phase, y: 0.5))
	}

	// How many letters are showing t seconds after the word appeared: one letter every letterSeconds, all of them after.
	static let letterSeconds = 0.22
	static func revealed(at t: Double, count: Int) -> Int {
		guard t >= 0 else { return 0 }
		return min(count, Int(t / letterSeconds) + 1)
	}

	@State private var appeared = Date()

	var body: some View {
		TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { context in
			let p = reduceMotion ? 0 : Self.phase(at: context.date.timeIntervalSinceReferenceDate)
			let ends = Self.points(phase: p)
			let shown = reduceMotion ? text.count : Self.revealed(at: context.date.timeIntervalSince(appeared), count: text.count)
			let font = Font.system(size: size, weight: .heavy, design: .rounded)
			// The whole word, in the rainbow, sets the size so nothing shifts; a mask lets one more letter through at a time.
			Text(text).font(font)
				.foregroundStyle(LinearGradient(stops: Self.stops(), startPoint: ends.start, endPoint: ends.end))
				.mask(alignment: .leading) { Text(String(text.prefix(shown))).font(font) }
		}
		.onAppear { appeared = Date() }
		.accessibilityLabel(Text(text))
	}
}
