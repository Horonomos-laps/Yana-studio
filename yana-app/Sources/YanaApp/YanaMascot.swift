import SwiftUI

// Yana's pixel rabbit with a laptop (from the HTML prototype in tools/yana-notch, Yana's own artwork), drawn on a canvas
// and animated by a tick: the ears twitch, the eyes blink now and then, and while Yana works a lit pixel runs along
// the laptop screen as if typing. A glow around it takes the state's color (green working, orange waiting, gray idle).

enum Mascot {
	static let columns = 20, rows = 15
	static let tickSeconds = 0.17

	// B, C: ear outer pixels; I: inner ear; W: face; E: eyes; R: nose; L: laptop lid; D: laptop base.
	static let base: [String] = [
		".....BB......CC.....",
		".....BB......CC.....",
		".....BI......IC.....",
		".....BI......IC.....",
		"....WWWWWWWWWWWW....",
		"...WWWWWWWWWWWWWW...",
		"...WWEEWWWWWWEEWW...",
		"...WWWWWWWWWWWWWW...",
		"....WWWWWRRWWWWW....",
		".....WWWWWWWWWW.....",
		"....LLLLLLLLLLLL....",
		"....LLLLLLLLLLLL....",
		"....LLLLLLLLLLLL....",
		"...DDDDDDDDDDDDDD...",
		"....................",
	]

	static let palette: [Character: UInt32] = [
		"B": 0x6D7CFF, "C": 0x35D0FF, "I": 0xDBE3FF, "W": 0xEEF2FF, "E": 0x1B2340,
		"R": 0xFF8FB1, "L": 0x9AA3B2, "D": 0x4A5470,
	]

	// The ears lean one pixel to the left or right every few ticks.
	static func earShift(tick: Int) -> Int {
		switch tick / 5 % 4 { case 1: -1; case 3: 1; default: 0 }
	}

	// The eyes close for one tick about every 2.5 seconds.
	static func blinking(tick: Int) -> Bool { tick % 15 == 0 }

	// Which of the laptop screen's columns is lit, 0 ..< 12, sweeping left to right then back.
	static func typingColumn(tick: Int) -> Int {
		let n = tick % 22
		return n < 12 ? n : 22 - n - 1
	}

	// The picture at a tick as (column, row, color) cells, so it can be checked without drawing it.
	static func cells(tick: Int, working: Bool, accent: UInt32) -> [(x: Int, y: Int, color: UInt32)] {
		var out: [(Int, Int, UInt32)] = []
		let shift = earShift(tick: tick), blink = blinking(tick: tick)
		for (y, row) in base.enumerated() {
			for (x, ch) in row.enumerated() {
				guard var color = palette[ch] else { continue }
				var px = x
				if y < 4 { px = x + shift }              // the ears
				if ch == "E", blink { color = palette["W"] ?? color }
				if working, (10 ... 12).contains(y), ch == "L", x - 4 == typingColumn(tick: tick) { color = accent }
				if px >= 0, px < columns { out.append((px, y, color)) }
			}
		}
		return out.map { (x: $0.0, y: $0.1, color: $0.2) }
	}
}

struct YanaMascot: View {
	var state: YanaRun.State = .working
	var width: CGFloat = 30
	var glow = true

	private var accent: UInt32 {
		switch state { case .idle: 0x8E8E93; case .working: 0x22C55E; case .waiting: 0xF59E0B }
	}

	var body: some View {
		let height = width * CGFloat(Mascot.rows) / CGFloat(Mascot.columns)
		TimelineView(.periodic(from: .now, by: Mascot.tickSeconds)) { context in
			let tick = Int(context.date.timeIntervalSinceReferenceDate / Mascot.tickSeconds)
			Canvas { gc, size in
				let unit = size.width / CGFloat(Mascot.columns)
				for cell in Mascot.cells(tick: tick, working: state == .working, accent: accent) {
					let rect = CGRect(x: CGFloat(cell.x) * unit, y: CGFloat(cell.y) * unit, width: unit + 0.5, height: unit + 0.5)
					gc.fill(Path(rect), with: .color(Color(hex: cell.color)))
				}
			}
			.frame(width: width, height: height)
			.shadow(color: glow ? Color(hex: accent).opacity(0.55) : .clear, radius: 4)
		}
		.accessibilityHidden(true)
	}
}
