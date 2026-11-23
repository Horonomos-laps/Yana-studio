import SwiftUI

// Yana's pixel rabbit with a laptop (from the HTML prototype in tools/yana-notch, Yana's own artwork), drawn on a canvas
// and animated smoothly from the clock rather than in steps: the ears sway by fractions of a pixel, the body bobs a
// little, the eyes close and open, and while Yana works a soft light glides along the laptop screen as if typing.
// A glow around it takes the state's color (green working, orange waiting, gray idle).

enum Mascot {
	static let columns = 20, rows = 15

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

	static let blinkEvery = 2.6, blinkLength = 0.16
	static let screenColumns = 12

	// Everything that moves, as smooth functions of time in seconds.
	struct Pose: Equatable {
		var ear: Double        // sideways sway of the ear tips in pixels, smaller toward the head
		var bob: Double        // body lift in pixels (0 ... about 0.6)
		var eyeOpen: Double    // 1 open ... 0 shut
		var light: Double      // position of the typing light along the screen, 0 ... screenColumns - 1
	}

	static func pose(time t: Double, working: Bool) -> Pose {
		let phase = t.truncatingRemainder(dividingBy: blinkEvery)
		let eye = phase < blinkLength ? abs(phase - blinkLength / 2) / (blinkLength / 2) : 1
		let speed = working ? 1.0 : 0.45
		return Pose(ear: 0.8 * sin(t * 2.4 * speed),
		            bob: 0.3 + 0.3 * sin(t * 5 * speed),
		            eyeOpen: eye,
		            light: Double(screenColumns - 1) * (0.5 + 0.5 * sin(t * 3.2)))
	}

	struct Cell: Equatable {
		var x: Double, y: Double, height: Double
		var color: UInt32
	}

	// One cell per lit pixel: x and y in pixel units (fractions allowed), height 1 except for closing eyes.
	static func cells(time t: Double, working: Bool, accent: UInt32) -> [Cell] {
		let pose = pose(time: t, working: working)
		var out: [Cell] = []
		for (y, row) in base.enumerated() {
			for (x, ch) in row.enumerated() {
				guard let color = palette[ch] else { continue }
				var px = Double(x), py = Double(y) - (y < 13 ? pose.bob : 0), h = 1.0, c = color
				if y < 4 { px += pose.ear * (1 - Double(y) / 4) }              // ears sway most at the tips
				if ch == "E" { h = max(0.12, pose.eyeOpen); py += (1 - h) / 2 }  // eyes squeeze shut from the middle
				if working, (10 ... 12).contains(y), ch == "L" {
					let d = abs(Double(x - 4) - pose.light)
					let k = max(0, 1 - d / 1.8)                                   // a soft light about three pixels wide
					c = mix(color, accent, k)
				}
				out.append(Cell(x: px, y: py, height: h, color: c))
			}
		}
		return out
	}

	static func mix(_ a: UInt32, _ b: UInt32, _ k: Double) -> UInt32 {
		func part(_ shift: UInt32) -> UInt32 {
			let x = Double((a >> shift) & 0xFF), y = Double((b >> shift) & 0xFF)
			return UInt32((x + (y - x) * min(1, max(0, k))).rounded()) << shift
		}
		return part(16) | part(8) | part(0)
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
		TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
			let t = context.date.timeIntervalSinceReferenceDate
			Canvas { gc, size in
				let unit = size.width / CGFloat(Mascot.columns)
				for cell in Mascot.cells(time: t, working: state == .working, accent: accent) {
					let rect = CGRect(x: cell.x * unit, y: cell.y * unit, width: unit + 0.4, height: cell.height * unit + 0.4)
					gc.fill(Path(rect), with: .color(Color(hex: cell.color)))
				}
			}
			.frame(width: width, height: height)
			.shadow(color: glow ? Color(hex: accent).opacity(0.5) : .clear, radius: 4)
		}
		.accessibilityHidden(true)
	}
}
